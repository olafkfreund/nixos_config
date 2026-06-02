{ config
, lib
, ...
}:
let
  inherit (lib) mkIf mkEnableOption mkAfter;
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

    # Silence the `zoxide doctor` periodic-nag that prints multi-line
    # warnings on every shell invocation when it detects "issues" (newer
    # db version, missing shell hook, etc). Documented escape hatch in
    # zoxide's source: https://github.com/ajeetdsouza/zoxide
    home.sessionVariables._ZO_DOCTOR = "0";

    # Manually initialize zoxide at the very end of zsh configuration
    # This ensures it loads after all hooks and other integrations
    programs.zsh.initContent = mkAfter ''
      # Initialize zoxide (must be at the end of configuration)
      eval "$(${config.programs.zoxide.package}/bin/zoxide init zsh --cmd cd)"
    '';
  };
}
