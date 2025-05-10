{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.programs.obsidian.enable;
in {
  options.programs.obsidian = {
    enable = mkEnableOption "Obsidian markdown editor";
  };

  config = mkIf cfg {
    environment.systemPackages = with pkgs; [
      (pkgs.writeShellScriptBin "obsidian-wayland" ''
        #!/bin/sh
        # Launch Obsidian with Wayland optimizations
        exec ${pkgs.obsidian}/bin/obsidian \
          --enable-features=UseOzonePlatform,WaylandWindowDecorations,WebRTCPipeWireCapturer \
          --ozone-platform=wayland \
          --enable-wayland-ime \
          --enable-gpu-rasterization \
          --enable-zero-copy \
          --ignore-gpu-blocklist \
          "$@"
      '')
      obsidian
      obsidian-export
    ];
    
    # Create a desktop entry that uses our optimized launcher
    xdg.desktopEntries.obsidian-wayland = {
      name = "Obsidian (Wayland)";
      exec = "obsidian-wayland %F";
      icon = "obsidian";
      comment = "Knowledge base that works on top of a local folder of plain text Markdown files";
      desktopName = "Obsidian (Wayland)";
      genericName = "Note Taking";
      categories = [ "Office" "Utility" ];
      mimeType = [ "text/markdown" "x-scheme-handler/obsidian" ];
    };
  };
}
