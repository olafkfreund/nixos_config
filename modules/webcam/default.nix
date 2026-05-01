{ pkgs
, config
, lib
, ...
}:
let
  inherit (lib) mkIf mkEnableOption;
  cfg = config.programs.webcam;
in
{
  options.programs.webcam = {
    enable = mkEnableOption {
      default = false;
      description = "Webcam";
    };
  };
  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      droidcam
      adb-sync
    ];
  };
}
