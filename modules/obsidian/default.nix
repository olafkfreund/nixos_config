{ config
, lib
, pkgs
, ...
}:
with lib; let
  cfg = config.programs.obsidian.enable;
in
{
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
  };
}
