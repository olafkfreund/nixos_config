# Flatpak Application Management Module
# Enables Flatpak with automatic Flathub repository setup
{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.modules.services.flatpak;
in {
  options.modules.services.flatpak = {
    enable = mkEnableOption "Flatpak application management";

    autoAddFlathub = mkOption {
      type = types.bool;
      default = true;
      description = ''Automatically add Flathub repository on system startup'';
      example = false;
    };

    repositorySetup = {
      maxRetries = mkOption {
        type = types.int;
        default = 3;
        description = ''Maximum number of retry attempts for repository setup'';
        example = 5;
      };

      retryDelay = mkOption {
        type = types.int;
        default = 5;
        description = ''Base delay in seconds between retry attempts'';
        example = 10;
      };
    };
  };

  config = mkIf cfg.enable {
    # Enable Flatpak service
    services.flatpak.enable = true;

    # Automatic Flathub repository setup
    systemd.services.flatpak-repo = mkIf cfg.autoAddFlathub {
      description = "Add Flathub repository to Flatpak";
      wantedBy = ["multi-user.target"];
      after = ["network-online.target"];
      wants = ["network-online.target"];
      path = [pkgs.flatpak];
      serviceConfig = {
        Type = "oneshot";
        Restart = "on-failure";
        RestartSec = "${toString cfg.repositorySetup.retryDelay}s";
      };
      script = ''
        # Try up to configured attempts with increasing delays
        max_attempts=${toString cfg.repositorySetup.maxRetries}
        attempt=1

        while [ $attempt -le $max_attempts ]; do
          echo "Attempt $attempt to add flathub repository..."
          if flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo; then
            echo "Successfully added flathub repository."
            exit 0
          fi

          # If this isn't the last attempt, wait before retrying
          if [ $attempt -lt $max_attempts ]; then
            sleep_time=$((attempt * ${toString cfg.repositorySetup.retryDelay}))
            echo "Failed to add flathub repository. Retrying in $sleep_time seconds..."
            sleep $sleep_time
          fi

          attempt=$((attempt + 1))
        done

        echo "Failed to add flathub repository after $max_attempts attempts."
        exit 1
      '';
    };

    # Validation
    assertions = [
      {
        assertion = cfg.repositorySetup.maxRetries > 0;
        message = "Repository setup max retries must be greater than 0";
      }
      {
        assertion = cfg.repositorySetup.retryDelay > 0;
        message = "Repository setup retry delay must be greater than 0 seconds";
      }
    ];

    # Helpful warnings
    warnings = [
      (mkIf (!cfg.autoAddFlathub) ''
        Flatpak is enabled but automatic Flathub repository setup is disabled.
        You may need to manually add repositories with: flatpak remote-add flathub https://flathub.org/repo/flathub.flatpakrepo
      '')
    ];
  };
}
