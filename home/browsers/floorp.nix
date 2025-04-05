{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.browsers.floorp;
in {
  options.browsers.floorp = {
    enable = mkEnableOption {
      default = false;
      description = "Enable floorp browser";
    };
  };
  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      floorp
    ];
  };
}
