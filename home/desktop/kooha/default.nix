{ pkgs
, config
, lib
, ...
}:
with lib; let
  cfg = config.desktop.screenshots.kooha;
in
{
  options.desktop.screenshots.kooha = {
    enable = mkEnableOption {
      default = false;
      description = "Enable Kooha screenshots";
    };
  };
  config = mkIf cfg.enable {
    home.packages = [
      pkgs.kooha
    ];
  };
}
