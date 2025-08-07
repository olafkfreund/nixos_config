{ pkgs
, config
, lib
, ...
}:
with lib; let
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
