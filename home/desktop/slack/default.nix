{
  lib,
  config,
  inputs,
  pkgs,
  ...
}: with lib; let
  cfg = config.programs.slack;
in {
  options.programs.slack = {
    enable = mkEnableOption {
      default = false; 
      description = "Slack";
    };
  };
  config = mkIf cfg.enable {
    xdg.mimeApps.defaultApplications = {
      "x-scheme-handler/slack" = "slack-wayland.desktop";
    };
    
    # Create a Wayland-optimized launcher script for Slack
    home.packages = with pkgs; [
      # Original slack package
      slack
      
      # Wayland-optimized launcher
      (pkgs.writeShellScriptBin "slack-wayland" ''
        #!/bin/sh
        # Launch Slack with Wayland optimizations
        ELECTRON_OZONE_PLATFORM_HINT=wayland \
        NIXOS_OZONE_WL=1 \
        exec ${pkgs.slack}/bin/slack \
          --enable-features=UseOzonePlatform,WaylandWindowDecorations,WebRTCPipeWireCapturer \
          --ozone-platform=wayland \
          --enable-wayland-ime \
          --enable-gpu-rasterization \
          --enable-zero-copy \
          --ignore-gpu-blocklist \
          "$@"
      '')
    ];
    
    # Create a custom desktop entry that uses our Wayland launcher
    xdg.desktopEntries.slack-wayland = {
      name = "Slack (Wayland)";
      exec = "slack-wayland %U";
      icon = "slack";
      comment = "Slack optimized for Wayland";
      desktopName = "Slack (Wayland)";
      genericName = "Team Communication";
      categories = ["Network" "InstantMessaging"];
      mimeType = ["x-scheme-handler/slack"];
    };
  };
}
