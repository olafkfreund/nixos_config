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
    };
  };
}
