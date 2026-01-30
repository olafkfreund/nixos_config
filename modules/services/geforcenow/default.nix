# NVIDIA GeForce NOW Cloud Gaming Module
# Enables GeForce NOW native Linux client via Flatpak
{ config
, lib
, pkgs
, ...
}:
with lib; let
  cfg = config.modules.services.geforcenow;
in
{
  options.modules.services.geforcenow = {
    enable = mkEnableOption "NVIDIA GeForce NOW cloud gaming client";

    autoInstall = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Automatically install GeForce NOW Flatpak on system startup.
        If disabled, the remote will be added but installation must be done manually.
      '';
      example = false;
    };

    waylandFix = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Apply Wayland fix by disabling Wayland socket for GeForce NOW.
        Enable this if the application window doesn't open on Wayland.
      '';
      example = true;
    };

    remoteSetup = {
      maxRetries = mkOption {
        type = types.int;
        default = 3;
        description = ''Maximum number of retry attempts for repository setup'';
        example = 5;
      };

      retryDelay = mkOption {
        type = types.int;
        default = 10;
        description = ''Base delay in seconds between retry attempts'';
        example = 15;
      };
    };
  };

  config = mkIf cfg.enable {
    # Ensure Flatpak is enabled (dependency)
    modules.services.flatpak.enable = true;

    # Add NVIDIA GeForce NOW Flatpak remote and install app
    systemd.services.geforcenow-setup = {
      description = "Setup NVIDIA GeForce NOW Flatpak repository and install app";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" "flatpak-repo.service" ];
      wants = [ "network-online.target" ];
      requires = [ "flatpak-repo.service" ];
      path = [ pkgs.flatpak ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        Restart = "on-failure";
        RestartSec = "${toString cfg.remoteSetup.retryDelay}s";
      };

      script = ''
        max_attempts=${toString cfg.remoteSetup.maxRetries}
        attempt=1

        # Step 1: Add GeForce NOW Flatpak remote
        echo "Adding NVIDIA GeForce NOW Flatpak remote..."
        while [ $attempt -le $max_attempts ]; do
          echo "Attempt $attempt to add GeForce NOW repository..."

          if flatpak remote-add --system --if-not-exists GeForceNOW \
               https://international.download.nvidia.com/GFNLinux/flatpak/geforcenow.flatpakrepo; then
            echo "Successfully added GeForce NOW repository."
            break
          fi

          if [ $attempt -lt $max_attempts ]; then
            sleep_time=$((attempt * ${toString cfg.remoteSetup.retryDelay}))
            echo "Failed to add repository. Retrying in $sleep_time seconds..."
            sleep $sleep_time
          fi

          attempt=$((attempt + 1))
        done

        if [ $attempt -gt $max_attempts ]; then
          echo "Failed to add GeForce NOW repository after $max_attempts attempts."
          exit 1
        fi

        ${optionalString cfg.autoInstall ''
          # Step 2: Ensure flathub remote is available for runtimes
          echo "Ensuring flathub remote is available..."
          flatpak remote-add --system --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo || true

          # Wait for remote metadata to be fetched
          sleep 3

          # Step 3: Install required runtimes from flathub
          echo "Installing required Freedesktop runtimes..."
          attempt=1
          runtimes_installed=false

          while [ $attempt -le $max_attempts ]; do
            echo "Attempt $attempt to install runtimes..."

            if flatpak install -y --system --from https://dl.flathub.org/repo/appstream/org.freedesktop.Platform.flatpakref 2>/dev/null || \
               flatpak install -y --system flathub org.freedesktop.Platform//24.08 2>/dev/null; then
              echo "Freedesktop Platform runtime installed."
              runtimes_installed=true
              break
            fi

            if [ $attempt -lt $max_attempts ]; then
              sleep_time=$((attempt * ${toString cfg.remoteSetup.retryDelay}))
              echo "Failed to install runtimes. Retrying in $sleep_time seconds..."
              sleep $sleep_time
            fi

            attempt=$((attempt + 1))
          done

          if [ "$runtimes_installed" = "false" ]; then
            echo "Warning: Could not install Freedesktop runtimes automatically."
            echo "GeForce NOW may not work until runtimes are installed."
            echo "Try manually: flatpak install --system flathub org.freedesktop.Platform//24.08"
          fi

          # Step 4: Install GeForce NOW app
          echo "Installing NVIDIA GeForce NOW..."
          attempt=1

          while [ $attempt -le $max_attempts ]; do
            echo "Attempt $attempt to install GeForce NOW..."

            if flatpak install -y --system GeForceNOW com.nvidia.geforcenow; then
              echo "Successfully installed GeForce NOW."
              break
            fi

            if [ $attempt -lt $max_attempts ]; then
              sleep_time=$((attempt * ${toString cfg.remoteSetup.retryDelay}))
              echo "Failed to install. Retrying in $sleep_time seconds..."
              sleep $sleep_time
            fi

            attempt=$((attempt + 1))
          done

          if [ $attempt -gt $max_attempts ]; then
            echo "Warning: Failed to install GeForce NOW after $max_attempts attempts."
            echo "You can try manually: flatpak install --system GeForceNOW com.nvidia.geforcenow"
          fi
        ''}

        ${optionalString cfg.waylandFix ''
          # Step 3: Apply Wayland fix if enabled
          echo "Applying Wayland fix for GeForce NOW..."
          flatpak override --system --nosocket=wayland com.nvidia.geforcenow || true
          echo "Wayland fix applied."
        ''}

        echo "GeForce NOW setup completed."
      '';
    };

    # Validation
    assertions = [
      {
        assertion = cfg.remoteSetup.maxRetries > 0;
        message = "GeForce NOW remote setup max retries must be greater than 0";
      }
      {
        assertion = cfg.remoteSetup.retryDelay > 0;
        message = "GeForce NOW remote setup retry delay must be greater than 0 seconds";
      }
    ];

    # Information message
    warnings = mkIf (!cfg.autoInstall) [
      ''
        GeForce NOW module is enabled but autoInstall is disabled.
        The GeForce NOW remote will be added, but you need to install manually:
          flatpak install --system GeForceNOW com.nvidia.geforcenow
      ''
    ];
  };
}
