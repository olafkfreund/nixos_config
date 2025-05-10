{
  lib,
  config,
  inputs,
  pkgs,
  ...
}:
with lib; let
  cfg = config.programs.discord-wayland;
in {
  options.programs.discord-wayland = {
    enable = mkEnableOption {
      default = false;
      description = "Wayland-optimized Discord/Vesktop";
    };
  };
  config = mkIf cfg.enable {
    xdg.mimeApps.defaultApplications = {
      "x-scheme-handler/discord" = "vesktop-wayland.desktop";
    };

    # Create Wayland-optimized launcher script for Discord
    home.packages = with pkgs; [
      # Original Discord/Vesktop package
      vesktop

      # Wayland-optimized launcher
      (pkgs.writeShellScriptBin "vesktop-wayland" ''
        #!/bin/sh
        # Launch Discord/Vesktop with Wayland optimizations
        ELECTRON_OZONE_PLATFORM_HINT=wayland \
        NIXOS_OZONE_WL=1 \
        exec ${pkgs.vesktop}/bin/vesktop \
          --enable-features=UseOzonePlatform,WaylandWindowDecorations,WebRTCPipeWireCapturer \
          --ozone-platform=wayland \
          --enable-wayland-ime \
          --enable-gpu-rasterization \
          --enable-zero-copy \
          --ignore-gpu-blocklist \
          --enable-hardware-overlays \
          "$@"
      '')
    ];

    # Create a custom desktop entry that uses our Wayland launcher
    xdg.desktopEntries.vesktop-wayland = {
      name = "Discord (Wayland)";
      exec = "vesktop-wayland %U";
      icon = "vesktop";
      comment = "Discord optimized for Wayland";
      genericName = "Chat and Voice";
      categories = ["Network" "InstantMessaging"];
      mimeType = ["x-scheme-handler/discord"];
    };
  };
}
