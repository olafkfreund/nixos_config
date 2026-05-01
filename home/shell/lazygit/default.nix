{ config
, lib
, pkgs
, ...
}:
let
  inherit (lib) mkIf mkEnableOption;
  cfg = config.programs.lazygit;
in
{
  options.programs.lazygit = {
    enable = mkEnableOption "lazygit";
  };

  config = mkIf cfg.enable {
    home.packages = [ pkgs.lazygit ];
    # Add any other lazygit-specific configuration here
  };
}
