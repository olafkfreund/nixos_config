{ config
, lib
, ...
}:
with lib; let
  cfg = config.cli.zoxide;
in
{
  options.cli.zoxide = {
    enable = mkEnableOption {
      default = true;
      description = "Enable zoxide";
    };
  };
  config = mkIf cfg.enable {
    programs.zoxide = {
      enable = true;
      enableBashIntegration = true;
      # Disable auto-integration to manually initialize at the end of zshrc
      enableZshIntegration = false;
      options = [ "--cmd cd" ];
    };

    # Manually initialize zoxide at the very end of zsh configuration
    # This ensures it loads after all hooks and other integrations
    programs.zsh.initContent = mkAfter ''
      # Initialize zoxide (must be at the end of configuration)
      eval "$(${config.programs.zoxide.package}/bin/zoxide init zsh --cmd cd)"
    '';
  };
}
