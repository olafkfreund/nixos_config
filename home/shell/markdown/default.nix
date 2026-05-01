{ config
, lib
, pkgs
, ...
}:
let
  inherit (lib) mkIf mkEnableOption types;
  cfg = config.cli.markdown;
in
{
  options.cli.markdown = with types; {
    enable = mkEnableOption {
      default = false;
      description = "Include markdown syntax highlighting";
    };
  };
  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      mdr
      slippy
      md-tui
    ];
  };
}
