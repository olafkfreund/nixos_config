{ pkgs
, config
, lib
, ...
}:
let
  inherit (lib) mkIf;
  cfg = config.features.browsers;
in
{

  config = mkIf (cfg.enable && cfg.brave) {
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
        { id = "eimadpbcbfnmbkopoojfekhnkhdbieeh"; } # Dark Reader
      ];
    };
  };
}
