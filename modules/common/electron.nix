# modules/desktop/electron.nix
{ config
, lib
, pkgs
, ...
}:
with lib; let
  cfg = config.electron-apps;
in
{
  options.electron-apps = {
    enable = mkEnableOption "Electron applications with Wayland optimizations";

    networkStability = mkOption {
      type = types.bool;
      default = false;
      description = "Enable network stability enhancements for Electron apps";
      example = true;
    };
  };

  config = mkIf cfg.enable {
    # Ensure Wayland environment is enabled
    wayland-environment.enable = true;

    # Common electron flags
    environment.variables = {
      ELECTRON_OZONE_PLATFORM_HINT = "auto";
    };

    # Set up network stability configuration in home directories
    system.activationScripts.electronNetworkStability = mkIf cfg.networkStability (
      let
        electronConfigContent = ''
          --disable-background-networking=false
          --force-fieldtrials="NetworkQualityEstimator/Enabled/"
          --enable-features=NetworkServiceInProcess
        '';
      in
      ''
        # Create Electron flags configuration file for each user
        for userDir in /home/*; do
          if [ -d "$userDir" ]; then
            username=$(basename "$userDir")
            configDir="$userDir/.config"
            mkdir -p "$configDir" || true
            echo "${electronConfigContent}" > "$configDir/electron-flags.conf"
            chown "$username:$(id -g "$username" 2>/dev/null || echo users)" "$configDir/electron-flags.conf"
          fi
        done
      ''
    );

    # Global wrapper script for Electron apps with network improvements
    environment.systemPackages = [
      (pkgs.writeShellScriptBin "electron-wayland-launcher" ''
        #!/bin/sh
        # Usage: electron-wayland-launcher /path/to/electron/app [args...]
        export NIXOS_OZONE_WL=1
        export ELECTRON_OZONE_PLATFORM_HINT=wayland
        export ELECTRON_ENABLE_LOGGING=1
        # Add network-specific flags to improve stability
        ${optionalString cfg.networkStability ''
          export DISABLE_REQUEST_THROTTLING=1
          export ELECTRON_FORCE_WINDOW_MENU_BAR=1
          # Increase connection pools and timeouts
          export CHROME_NET_TCP_SOCKET_CONNECT_TIMEOUT_MS=60000
          export CHROME_NET_TCP_SOCKET_CONNECT_ATTEMPT_DELAY_MS=2000
        ''}
        exec "$@" --enable-features=UseOzonePlatform,WaylandWindowDecorations,WebRTCPipeWireCapturer${optionalString cfg.networkStability ",NetworkServiceInProcess,NetworkQualityEstimator"} --ozone-platform=wayland${optionalString cfg.networkStability " --disable-background-networking=false"}
      '')
    ];
  };
}
