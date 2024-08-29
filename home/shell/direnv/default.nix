{
  pkgs,
  config,
  lib,
  inputs,
  ...
}: 
with lib; let 
  cfg = config.cli.direnv;
in {
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
