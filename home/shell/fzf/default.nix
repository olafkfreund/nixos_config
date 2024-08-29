{
  input,
  lib,
  config,
  ...
}: 
with lib; let 
  cfg = config.cli.fzf;
in {
  options.cli.fzf = {
    enable = mkEnableOption {
      default = true;
      description = "Enable fuzzy finder";
    };
  };
  config = mkIf cfg.enable {
    programs.fzf = {
      enable = true;
      enableBashIntegration = true;
      enableZshIntegration = true;
    };
  };
}
