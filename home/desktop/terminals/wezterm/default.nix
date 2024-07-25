{pkgs, ...}: {
  programs.wezterm = {
    enable = true;
    package = pkgs.wezterm;
    enableBashIntegration = true;
    enableZshIntegration = true;
    extraConfig = ''
      return {
        hide_tab_bar_if_only_one_tab = true,
        color_scheme = 'Gruvbox dark, hard (base16)',
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
        }
       }
    '';
  };
}
