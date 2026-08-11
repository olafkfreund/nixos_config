{ config, lib, pkgs, ... }:

let
  inherit (lib) mkOption mkIf mkEnableOption mkPackageOption mkAfter types getExe optionalString;
  cfg = config.programs.splashboard;

  # settings.toml is parametrised (theme name is an option), so generate it
  # via pkgs.formats.toml. The two dashboard .toml files are static assets
  # next to this default.nix.
  # Alien HUD tokens, derived from the Stylix base16 scheme so the splash
  # matches niri's borders, the terminals and both shells. Per-token entries in
  # [theme] override the preset, so `cfg.theme` only supplies anything left out
  # here (in practice: nothing — every token splashboard defines is set).
  #
  # bg / bg_subtle are "reset", NOT a colour: that is splashboard's escape hatch
  # for Color::Reset, so the viewport and the `bg = "subtle"` bands in the
  # dashboard TOMLs inherit the terminal's own background. Without it the splash
  # paints a solid rectangle over the terminal — which would hide the plate that
  # ghostty/kitty render behind the text.
  themeTokens =
    let
      inherit (config.lib.stylix) colors;
      c = n: "#${colors.${n}}";
    in
    {
      preset = cfg.theme;

      bg = "reset";
      bg_subtle = "reset";

      text = c "base05"; # plate cream
      text_secondary = c "base04";
      text_dim = c "base03"; # chrome / placeholders

      panel_border = c "base03"; # hairline boxes
      panel_title = c "base0B"; # phosphor green headers

      status_ok = c "base0B";
      status_warn = c "base09"; # amber
      status_error = c "base08";

      accent_today = c "base0A";
      accent_event = c "base0C";

      # Chart series in the order the HUD's telemetry legend uses them:
      # green THRUST, orange CHAMBER P, blue-grey COOLANT dT, then amber/purple.
      palette_series = [ (c "base0B") (c "base09") (c "base0C") (c "base0A") (c "base0E") ];

      # Breaker-matrix ramp: near-background through to full phosphor green.
      palette_heatmap = [ (c "base01") (c "base02") (c "base03") (c "base04") (c "base0B") ];
    };

  settingsToml = (pkgs.formats.toml { }).generate "splashboard-settings.toml" {
    general = {
      height = cfg.height;
      auto_home = true;
      auto_on_cd = true;
    };
    theme = themeTokens;
  };
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

    theme = mkOption {
      type = types.enum [
        "default"
        "tokyo_night"
        "nord"
        "dracula"
        "gruvbox_dark"
        "gruvbox_light"
        "catppuccin_mocha"
      ];
      default = "gruvbox_dark";
      example = "tokyo_night";
      description = ''
        Splashboard colour theme preset. Written to ~/.splashboard/settings.toml
        as `[theme] preset = "<this>"`. See
        https://splashboard.unhappychoice.com/showcases/themes/ for the list
        and screenshots.
      '';
    };

    height = mkOption {
      type = types.ints.positive;
      default = 30;
      description = ''
        Total dashboard render height in terminal rows. Tune to taste
        relative to your terminal window size — splashboard fits widgets
        into this height; anything that doesn't fit is clipped.
      '';
    };

    enableDashboards = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Render the bundled home + project dashboard TOML files from this
        module into ~/.splashboard/. Set to false to manage these by hand.
      '';
    };

    githubTokenFile = mkOption {
      type = types.nullOr types.path;
      default = "/run/agenix/api-github-token";
      example = lib.literalExpression "null";
      description = ''
        Path to a file containing a GitHub personal access token, exported
        as GH_TOKEN in zsh sessions so splashboard's github_* widgets work.
        Default points at the agenix-decrypted runtime path. Set to null to
        skip the export entirely (offline-only dashboards still render).

        The token is read at shell init time, NOT at evaluation time, so it
        never lands in the Nix store. Matches the zsh-ai-cmd pattern used
        elsewhere in this repo.
      '';
    };
  };

  config = mkIf cfg.enable {
    home.packages = [ cfg.package ];

    # Render config + dashboards under ~/.splashboard/. HM symlinks these
    # from /nix/store, so they're read-only — fine because splashboard
    # only READS them. The runtime-mutable bits (trust.toml, cache/,
    # store/) are deliberately NOT managed here.
    home.file = mkIf cfg.enableDashboards {
      ".splashboard/settings.toml".source = settingsToml;
      ".splashboard/home.dashboard.toml".source = ./home.dashboard.toml;
      ".splashboard/project.dashboard.toml".source = ./project.dashboard.toml;
    };

    # Wire the init eval after Starship and other prompt setup so the
    # splash renders against a fully-configured shell. Use mkAfter so the
    # hook lands at the end of programs.zsh.initContent.
    #
    # GH_TOKEN export must run BEFORE the eval so the chpwd hook (and the
    # initial render) sees the token.
    #
    # Opt-out env vars are handled by splashboard itself, not declaratively:
    #   - CI=1                 — auto-detected in CI environments
    #   - SPLASHBOARD_SILENT=1 — suppress this session
    #   - NO_SPLASHBOARD=1     — suppress permanently for shells where set
    #
    # Per-repo overrides live at ./.splashboard/dashboard.toml. Splashboard
    # gates these via ~/.splashboard/trust.toml (prompts on first entry to
    # an untrusted dir).
    programs.zsh.initContent = mkIf cfg.enableZshIntegration (mkAfter ''
      # ========================================
      # splashboard — shell startup dashboard
      # ========================================
      ${optionalString (cfg.githubTokenFile != null) ''
      if [[ -f "${toString cfg.githubTokenFile}" ]]; then
        export GH_TOKEN="$(cat "${toString cfg.githubTokenFile}")"
      fi
      ''}
      eval "$(${getExe cfg.package} init zsh)"
    '');
  };
}
