{ config
, lib
, pkgs
, ...
}:
let
  inherit (lib) mkIf;
  cfg = config.features.programs.obsidian;
in
{
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
  };
}
