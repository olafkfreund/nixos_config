# modules/desktop/electron.nix
{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.electron-apps;
in {
  options.electron-apps = {
    enable = mkEnableOption "Electron applications with Wayland optimizations";
  };

  config = mkIf cfg.enable {
    # Ensure Wayland environment is enabled
    wayland-environment.enable = true;

    # Common electron flags
    environment.variables = {
      ELECTRON_OZONE_PLATFORM_HINT = "auto";
    };

    # Global wrapper script for Electron apps
    environment.systemPackages = [
      (pkgs.writeShellScriptBin "electron-wayland-launcher" ''
        #!/bin/sh
        # Usage: electron-wayland-launcher /path/to/electron/app [args...]
        export NIXOS_OZONE_WL=1
        export ELECTRON_OZONE_PLATFORM_HINT=wayland
        export ELECTRON_ENABLE_LOGGING=1
        exec "$@" --enable-features=UseOzonePlatform,WaylandWindowDecorations,WebRTCPipeWireCapturer --ozone-platform=wayland
      '')
    ];
  };
}
