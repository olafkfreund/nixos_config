{
  pkgs,
  config,
  lib,
  ...
}:
with lib; let
  cfg = config.browsers.chrome;
in {
  options.browsers.chrome = {
    enable = mkEnableOption {
      default = false;
      description = "Enable Google Chrome";
    };
  };
  config = mkIf cfg.enable {
    programs.chromium = {
      enable = true;
      package = pkgs.google-chrome;
      commandLineArgs = [
        "--enable-features=UseOzonePlatform,WaylandWindowDecorations,WebRTCPipeWireCapturer"
        "--ozone-platform=wayland"
        "--enable-wayland-ime"
        "--enable-gpu-rasterization"
        "--enable-zero-copy"
        "--ignore-gpu-blocklist"
        "--enable-hardware-overlays"
        "--gtk-version=4"
      ];
    };
  };
}
