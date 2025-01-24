{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.ghostty;
in {
  options.ghostty = {
    enable = mkEnableOption {
      default = false;
      description = "ghostty";
    };
  };
  config = {
    programs.ghostty = {
      enable = true;
      package = pkgs.ghostty;
      settings = {
        theme = "GruvboxDark";
        font-size = 15;
        confirm-close-surface = false;
        window-decoration = false;
      };
    };
  };
}
