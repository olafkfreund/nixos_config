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
        commandLineArgs = ["--enable-features=UseOzonePlatform --ozone-platform=wayland --disable-gpu"];
      # commandLineArgs = [
      #   "--enable-features=UseOzonePlatform"
      #   "--ozone-platform=wayland"
      #   "--gtk-version=4"
      #   "--enable-wayland-ime"
      # ];
    };
  };  
}
