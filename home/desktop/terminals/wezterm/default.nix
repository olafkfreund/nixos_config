{
  pkgs,
  pkgs-stable,
  config,
  lib,
  ...
}:
with lib; let
  cfg = config.wezterm;
in {
  options.wezterm = {
    enable = mkEnableOption {
      default = false;
      description = "Enable wezterm";
    };
  };
  config = mkIf cfg.enable {
    programs.wezterm = {
      enable = true;
      package = pkgs.wezterm;
      enableBashIntegration = true;
      enableZshIntegration = true;
      extraConfig = ''
        return {
          hide_tab_bar_if_only_one_tab = true,
          color_scheme = 'Gruvbox dark, medium (base16)',
          keys = {
            {
              key = "LeftArrow",
              mods = "CTRL | SHIFT",
              action = wezterm.action { ActivateTabRelative = -1 }
            },
            {
              key = "RightArrow",
              mods = "CTRL | SHIFT",
              action = wezterm.action { ActivateTabRelative = 1 }
            },
            {
              key = "j",
              mods = "CTRL | SHIFT",
              action = wezterm.action { ScrollByLine = 1 }
            },
            {
              key = "k",
              mods = "CTRL | SHIFT",
              action = wezterm.action { ScrollByLine = -1 }
            },
            {
              key = "_",
              mods = "CTRL | SHIFT",
              action = wezterm.action.SplitHorizontal { domain = "CurrentPaneDomain" },
            },
            {
              key = "|",
              mods = "CTRL | ALT",
              action = wezterm.action.SplitVertical { domain = "CurrentPaneDomain" },
            },
            {
              key = "V",
              mods = "CTRL",
              action = wezterm.action.PasteFrom "Clipboard"
            },
            {
              key = "V",
              mods = "CTRL",
              action = wezterm.action.PasteFrom "PrimarySelection"
            },
            {
                key = "C",
                mods = "CTRL",
                action = wezterm.action.CopyTo "ClipboardAndPrimarySelection",
            },
          }
        }
      '';
    };
  };
}
