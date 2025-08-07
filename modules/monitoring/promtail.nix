# Promtail Log Collection Module
# Collects logs from systemd journal and sends to Loki
{ config
, lib
, ...
}:
with lib; let
  cfg = config.services.promtail-logging;
in
{
  options.services.promtail-logging = {
    enable = mkEnableOption "Promtail log collection for centralized logging";

    lokiUrl = mkOption {
      type = types.str;
      default = "http://dex5550:3100";
      description = "URL of the Loki server to send logs to";
    };

    hostname = mkOption {
      type = types.str;
      default = config.networking.hostName;
      description = "Hostname label for logs";
    };

    collectJournal = mkOption {
      type = types.bool;
      default = true;
      description = "Collect systemd journal logs";
    };

    collectKernel = mkOption {
      type = types.bool;
      default = true;
      description = "Collect kernel logs";
    };

    collectNginx = mkOption {
      type = types.bool;
      default = false;
      description = "Collect nginx access and error logs";
    };

    extraScrapeConfigs = mkOption {
      type = types.listOf types.attrs;
      default = [ ];
      description = "Additional scrape configurations";
    };
  };

  config = mkIf cfg.enable {
    services.promtail = {
      enable = true;

      configuration = {
        server = {
          http_listen_port = 9080;
          grpc_listen_port = 0;
        };

        positions = {
          filename = "/var/lib/promtail/positions.yaml";
        };

        clients = [
          {
            url = "${cfg.lokiUrl}/loki/api/v1/push";
            external_labels = {
              hostname = cfg.hostname;
              environment = "production";
              role =
                if config.networking.hostName == "dex5550" then "monitoring"
                else if config.networking.hostName == "p510" then "media-server"
                else if config.networking.hostName == "p620" then "workstation"
                else "client";
            };
          }
        ];

        scrape_configs =
          # Systemd journal logs
          (optionals cfg.collectJournal [
            {
              job_name = "journal";
              journal = {
                max_age = "12h";
                labels = {
                  job = "systemd-journal";
                  host = cfg.hostname;
                };
              };
              relabel_configs = [
                {
                  source_labels = [ "__journal__systemd_unit" ];
                  target_label = "unit";
                }
                {
                  source_labels = [ "__journal__hostname" ];
                  target_label = "hostname";
                }
                {
                  source_labels = [ "__journal_priority" ];
                  target_label = "priority";
                }
                {
                  source_labels = [ "__journal_transport" ];
                  target_label = "transport";
                }
              ];
            }
          ]) ++

          # Kernel logs
          (optionals cfg.collectKernel [
            {
              job_name = "kernel";
              static_configs = [
                {
                  targets = [ "localhost" ];
                  labels = {
                    job = "kernel";
                    host = cfg.hostname;
                    __path__ = "/dev/kmsg";
                  };
                }
              ];
            }
          ]) ++

          # Nginx logs (if enabled)
          (optionals cfg.collectNginx [
            {
              job_name = "nginx_access";
              static_configs = [
                {
                  targets = [ "localhost" ];
                  labels = {
                    job = "nginx";
                    type = "access";
                    host = cfg.hostname;
                    __path__ = "/var/log/nginx/access.log";
                  };
                }
              ];
            }
            {
              job_name = "nginx_error";
              static_configs = [
                {
                  targets = [ "localhost" ];
                  labels = {
                    job = "nginx";
                    type = "error";
                    host = cfg.hostname;
                    __path__ = "/var/log/nginx/error.log";
                  };
                }
              ];
            }
          ]) ++

          # Extra configurations
          cfg.extraScrapeConfigs;
      };
    };

    # Create necessary directories
    systemd.tmpfiles.rules = [
      "d /var/lib/promtail 0755 promtail promtail -"
    ];

    # Promtail user and group
    users.users.promtail = {
      isSystemUser = true;
      group = "promtail";
      home = "/var/lib/promtail";
      createHome = true;
      extraGroups = [ "systemd-journal" ]; # Access to journal
    };

    users.groups.promtail = { };

    # Systemd service optimizations
    systemd.services.promtail = {
      serviceConfig = {
        # Resource limits
        MemoryMax = "256M";
        CPUQuota = "50%";

        # Security hardening
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = [ "/var/lib/promtail" ];
        ReadOnlyPaths = [ "/var/log" "/dev/kmsg" ];

        # Restart policy
        Restart = lib.mkForce "always";
        RestartSec = "10s";

        # Health monitoring
        WatchdogSec = "120s";

        # Ensure access to journal
        SupplementaryGroups = [ "systemd-journal" ];
      };

      # Dependencies
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
    };

    # Log rotation for promtail logs
    services.logrotate.settings = {
      "/var/log/promtail/*.log" = {
        frequency = "daily";
        rotate = 7;
        compress = true;
        delaycompress = true;
        missingok = true;
        notifempty = true;
        create = "644 promtail promtail";
        postrotate = "systemctl reload promtail.service";
      };
    };
  };
}
