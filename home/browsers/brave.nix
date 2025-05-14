{
  pkgs,
  config,
  lib,
  ...
}:
with lib; let
  cfg = config.browsers.brave;
in {
  options.browsers.brave = {
    enable = mkEnableOption "Brave browser";
  };

  config = mkIf cfg.enable {
    programs.chromium = {
      enable = true;
      package = pkgs.brave;
      commandLineArgs = [
        "--enable-features=UseOzonePlatform,WaylandWindowDecorations,WebRTCPipeWireCapturer,VaapiVideoDecoder,VaapiVideoEncoder,VaapiIgnoreDriverChecks"
        "--ozone-platform=wayland"
        "--enable-wayland-ime"
        "--enable-gpu-rasterization"
        "--enable-zero-copy"
        "--ignore-gpu-blocklist"
        "--enable-hardware-overlays"
        "--enable-accelerated-video-decode"
        "--enable-accelerated-video-encode"
        "--use-gl=egl"
        "--force-dark-mode"
        "--gtk-version=4"
      ];
      extensions = [
        {id = "eimadpbcbfnmbkopoojfekhnkhdbieeh";} # Dark Reader
      ];
    };
  };
}
