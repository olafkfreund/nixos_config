{
  config,
  lib,
  pkgs,
  ...
}: 
with lib; let 
  cfg = config.browsers.brave;
in {
  options.browsers.brave = {
    enable = mkEnableOption {
      default = false; 
      description = "Brave browser";
    };
  };
  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      brave
    ];
  };
}
