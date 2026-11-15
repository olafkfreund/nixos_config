{ config
, lib
, ...
}:
let
  inherit (lib) mkIf;
  cfg = config.features.cli;
in
{
  config = mkIf (cfg.enable && cfg.direnv) {
    programs.direnv = {
      enable = true;
      enableBashIntegration = true;
      enableZshIntegration = true;
      nix-direnv.enable = true;
    };
  };
}
