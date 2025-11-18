{ config, lib, pkgs, ... }:
with lib;
let
  cfg = config.services.gitlab-runner-local;
in
{
  options.services.gitlab-runner-local = {
    enable = mkEnableOption "GitLab Runner for local CI/CD";

    registrationConfigFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = ''
        Path to file containing GitLab Runner registration token.
        This file should contain the registration token from your GitLab instance.

        Example file content:
        CI_SERVER_URL=https://gitlab.com
        REGISTRATION_TOKEN=your-registration-token-here
      '';
      example = "/run/agenix/gitlab-runner-token";
    };

    concurrent = mkOption {
      type = types.int;
      default = 4;
      description = "Maximum number of concurrent jobs";
    };

    checkInterval = mkOption {
      type = types.int;
      default = 0;
      description = "Check interval for new jobs (in seconds, 0 = default)";
    };

    services = mkOption {
      type = types.listOf (types.submodule {
        options = {
          name = mkOption {
            type = types.str;
            description = "Name of the runner service";
            example = "docker-runner";
          };

          url = mkOption {
            type = types.str;
            default = "https://gitlab.com";
            description = "GitLab instance URL";
          };

          executor = mkOption {
            type = types.enum [ "shell" "docker" "docker+machine" "kubernetes" ];
            default = "docker";
            description = "Executor type for running jobs";
          };

          dockerImage = mkOption {
            type = types.str;
            default = "alpine:latest";
            description = "Default Docker image for docker executor";
          };

          dockerPrivileged = mkOption {
            type = types.bool;
            default = false;
            description = "Run Docker containers in privileged mode";
          };

          dockerVolumes = mkOption {
            type = types.listOf types.str;
            default = [ "/cache" ];
            description = "Docker volumes to mount";
          };

          tagList = mkOption {
            type = types.listOf types.str;
            default = [ ];
            description = "Tags for this runner";
            example = [ "docker" "linux" "nix" ];
          };

          runUntagged = mkOption {
            type = types.bool;
            default = false;
            description = "Run jobs without tags";
          };

          limit = mkOption {
            type = types.int;
            default = 0;
            description = "Maximum number of jobs for this runner (0 = unlimited)";
          };
        };
      });
      default = [ ];
      description = "GitLab Runner service configurations";
    };
  };

  config = mkIf cfg.enable {
    # Ensure Docker is available for docker executor
    virtualisation.docker.enable = mkIf (any (s: s.executor == "docker" || s.executor == "docker+machine") cfg.services) true;

    # Create systemd service for GitLab Runner
    systemd.services.gitlab-runner = {
      description = "GitLab Runner";
      after = [ "network.target" ] ++ optional config.virtualisation.docker.enable "docker.service";
      wants = optional config.virtualisation.docker.enable "docker.service";
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "simple";
        User = "gitlab-runner";
        Group = "gitlab-runner";
        ExecStart = "${pkgs.gitlab-runner}/bin/gitlab-runner run --working-directory /var/lib/gitlab-runner --config /etc/gitlab-runner/config.toml --service gitlab-runner";
        Restart = "always";
        RestartSec = 10;

        # Security hardening
        PrivateTmp = true;
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = [ "/var/lib/gitlab-runner" ];

        # Resource limits
        MemoryMax = "4G";
        TasksMax = 1000;
      };

      preStart = ''
                # Create directories if they don't exist
                mkdir -p /etc/gitlab-runner
                mkdir -p /var/lib/gitlab-runner

                # Only create config if it doesn't exist (manual registration will create it)
                if [ ! -f /etc/gitlab-runner/config.toml ]; then
                  # Create minimal config.toml for manual registration
                  cat > /etc/gitlab-runner/config.toml <<EOF
        concurrent = ${toString cfg.concurrent}
        check_interval = ${toString cfg.checkInterval}
        log_level = "info"

        [session_server]
          session_timeout = 1800
        EOF
                fi

                # Set proper permissions
                chown -R gitlab-runner:gitlab-runner /etc/gitlab-runner
                chown -R gitlab-runner:gitlab-runner /var/lib/gitlab-runner
                chmod 700 /var/lib/gitlab-runner
                chmod 600 /etc/gitlab-runner/config.toml || true
      '';
    };

    # Create gitlab-runner user and group
    users = {
      users.gitlab-runner = {
        isSystemUser = true;
        group = "gitlab-runner";
        home = "/var/lib/gitlab-runner";
        createHome = true;
        description = "GitLab Runner user";
        # Add to docker group if docker executor is used
        extraGroups = optional (any (s: s.executor == "docker" || s.executor == "docker+machine") cfg.services) "docker";
      };

      groups.gitlab-runner = { };
    };

    # Install GitLab Runner package
    environment.systemPackages = [ pkgs.gitlab-runner ];

    # Firewall configuration (if needed for distributed runners)
    # networking.firewall.allowedTCPPorts = [ ];
  };
}
