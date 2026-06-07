{ config, lib, pkgs, ... }:

let
  inherit (lib) mkOption mkIf mkEnableOption types optional elem;
  cfg = config.features.homeAssistant;
in
{
  options.features.homeAssistant = {
    enable = mkEnableOption "Home Assistant home automation platform";

    port = mkOption {
      type = types.port;
      default = 8123;
      description = "Port for Home Assistant web interface";
    };

    enableCloud = mkOption {
      type = types.bool;
      default = true;
      description = "Enable Home Assistant Cloud (Nabu Casa) integration";
    };

    enableCLI = mkOption {
      type = types.bool;
      default = true;
      description = "Install Home Assistant CLI tool";
    };

    extraComponents = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Additional Home Assistant components to enable";
    };

    tailscaleIntegration = mkOption {
      type = types.bool;
      default = true;
      description = "Configure trusted proxies for Tailscale access";
    };

    dashboards = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          title = mkOption {
            type = types.str;
            description = "Sidebar display title";
          };
          icon = mkOption {
            type = types.str;
            default = "mdi:view-dashboard";
            description = "Material Design Icons name for the sidebar entry";
          };
          showInSidebar = mkOption {
            type = types.bool;
            default = true;
            description = "Show this dashboard in the HA sidebar";
          };
          yaml = mkOption {
            type = types.lines;
            description = ''
              Raw Lovelace dashboard YAML. Must define `title:` and `views:`.
              Written to /etc/home-assistant/dashboards/<name>.yaml at activation;
              referenced from configuration.yaml via lovelace.dashboards.
            '';
          };
        };
      });
      default = { };
      description = ''
        Declarative Lovelace dashboards. Each attr key becomes the URL slug
        (/<key>) and the corresponding YAML is rendered into a read-only file
        under /etc/home-assistant/dashboards/. The default Overview dashboard
        remains in storage mode and is unaffected.
      '';
    };
  };

  config = mkIf cfg.enable {
    # Home Assistant service configuration
    services.home-assistant = {
      enable = true;

      extraPackages = python3Packages: with python3Packages; [
        python-otbr-api
        pychromecast
        androidtvremote2
      ];

      # Declarative configuration
      config = {
        # Enable the default_config meta-component which activates the essential
        # components listed in extraComponents below (my, mobile_app, network,
        # automation, scene, script, etc). Without this, those components are
        # installed but never loaded — breaking my.home-assistant.io redirects
        # and many integrations that depend on application_credentials.
        default_config = { };

        # HTTP configuration
        http = {
          server_host = "0.0.0.0";
          server_port = cfg.port;
          use_x_forwarded_for = cfg.tailscaleIntegration;
          trusted_proxies = mkIf cfg.tailscaleIntegration [
            "127.0.0.1"
            "::1"
            "100.64.0.0/10" # Tailscale CGNAT range
            "192.168.1.0/24" # Local network
          ];
        };

        # Homeassistant configuration
        homeassistant = {
          name = "P510 Home";
          unit_system = "metric";
          time_zone = "UTC"; # Should match system timezone
          external_url = "https://p510.home.freundcloud.com:8123"; # Adjust based on Tailscale hostname
        };
      };

      # Declarative Lovelace dashboards (in addition to the default storage-mode one)
      config.lovelace.dashboards = lib.mapAttrs
        (name: d: {
          mode = "yaml";
          filename = "/etc/home-assistant/dashboards/${name}.yaml";
          title = d.title;
          icon = d.icon;
          show_in_sidebar = d.showInSidebar;
          require_admin = false;
        })
        cfg.dashboards;

      # Components required for onboarding + optional cloud
      extraComponents = [
        # Required for initial onboarding
        "analytics"
        "met"
        "radio_browser"
        "shopping_list"

        # Essential components usually in default_config
        "assist_pipeline"
        "backup"
        "bluetooth"
        "config"
        "conversation"
        "dhcp"
        "energy"
        "history"
        "homeassistant_alerts"
        "image_upload"
        "logbook"
        "media_source"
        "mobile_app"
        "my"
        "network"
        "person"
        "repairs"
        "scene"
        "script"
        "ssdp"
        "sun"
        "system_health"
        "tag"
        "usb"
        "webhook"
        "zeroconf"
        "zone"
      ] ++ optional cfg.enableCloud "cloud"
      ++ cfg.extraComponents;
    };

    # Systemd service hardening
    systemd.services.home-assistant = {
      serviceConfig = {
        # Security hardening
        DynamicUser = true;
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        RestrictSUIDSGID = true;

        # Resource limits
        MemoryMax = "2G";
        TasksMax = 512;

        # Required paths for Home Assistant
        ReadWritePaths = [
          "/var/lib/hass" # Home Assistant state directory
        ];
      };
    };

    # Materialize each declared dashboard as a read-only file under /etc.
    # HA reads /etc as read-only under ProtectSystem=strict, so this works
    # without weakening the service hardening or touching /var/lib/hass.
    environment.etc = lib.mapAttrs'
      (name: d: lib.nameValuePair "home-assistant/dashboards/${name}.yaml" {
        text = d.yaml;
        mode = "0444";
      })
      cfg.dashboards;

    # Home Assistant CLI tool
    environment.systemPackages = mkIf cfg.enableCLI [
      pkgs.home-assistant-cli
    ];

    # Firewall configuration
    networking.firewall = mkIf config.networking.firewall.enable {
      allowedTCPPorts = [ cfg.port ];
    };

    # Assertions
    assertions = [
      {
        assertion = cfg.enableCloud -> elem "cloud" config.services.home-assistant.extraComponents;
        message = "Home Assistant Cloud requires 'cloud' component in extraComponents";
      }
      {
        assertion = lib.all (n: lib.hasInfix "-" n) (lib.attrNames cfg.dashboards);
        message = ''
          Each features.homeAssistant.dashboards attribute name (the URL slug)
          must contain a hyphen — Home Assistant's lovelace integration rejects
          single-word slugs at runtime. Offenders: ${
            lib.concatStringsSep ", "
              (lib.filter (n: !(lib.hasInfix "-" n)) (lib.attrNames cfg.dashboards))
          }
        '';
      }
    ];
  };
}
