{ config
, lib
, pkgs
, ...
}:
let
  inherit (lib) mkIf mkEnableOption;
  cfg = config.browsers.edge;
in
{
  options.browsers.edge = {
    enable = mkEnableOption {
      default = false;
      description = "Microsoft Edge";
    };
  };
  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      microsoft-edge
      # microsoft-edge-dev
    ];
  };
}
