{ config
, lib
, ...
}:
let
  inherit (lib) mkIf mkEnableOption;
  cfg = config.cli.direnv;
in
{
  options.cli.direnv = {
    enable = mkEnableOption {
      default = true;
      description = "direnv";
    };
  };
  config = mkIf cfg.enable {
    programs.direnv = {
      enable = true;
      enableBashIntegration = true;
      enableZshIntegration = true;
      nix-direnv.enable = true;
    };
  };
}
