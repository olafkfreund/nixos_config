{ config, lib, pkgs, ... }:

let
  inherit (lib) mkOption mkIf mkEnableOption mkPackageOption mkAfter types getExe;
  cfg = config.programs.splashboard;
in
{
  options.programs.splashboard = {
    enable = mkEnableOption "splashboard terminal splash screen on shell startup";

    package = mkPackageOption pkgs "splashboard" { };

    enableZshIntegration = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Wire `eval "$(splashboard init zsh)"` into the zsh init.

        The hook renders a TUI dashboard on every new interactive shell and
        on `cd` into a directory. Set to false to install the binary but
        skip the init hook (you can still invoke `splashboard` manually).
      '';
    };
  };

  config = mkIf cfg.enable {
    home.packages = [ cfg.package ];

    # Wire the init eval after Starship and other prompt setup so the
    # splash renders against a fully-configured shell. Use mkAfter so the
    # hook lands at the end of programs.zsh.initContent.
    #
    # Opt-out env vars are handled by splashboard itself, not declaratively:
    #   - CI=1                 — auto-detected in CI environments
    #   - SPLASHBOARD_SILENT=1 — suppress this session
    #   - NO_SPLASHBOARD=1     — suppress permanently for shells where set
    #
    # Per-repo overrides live at ./.splashboard/dashboard.toml. Splashboard
    # gates these via ~/.splashboard/trust.toml (prompts on first entry to
    # an untrusted dir). User config lives at $HOME/.splashboard/ — override
    # location via the SPLASHBOARD_HOME env var.
    programs.zsh.initContent = mkIf cfg.enableZshIntegration (mkAfter ''
      # ========================================
      # splashboard — shell startup dashboard
      # ========================================
      eval "$(${getExe cfg.package} init zsh)"
    '');
  };
}
