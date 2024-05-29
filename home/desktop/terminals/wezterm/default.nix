{ pkgs-stable, config, ... }:{
  
  programs.wezterm = {
    enable = true;
    package = pkgs-stable.wezterm;
    enableBashIntegration = true;
    enableZshIntegration = true;
    extraConfig = ''
      return {
        hide_tab_bar_if_only_one_tab = true,
        keys = {
          {
            key = "LeftArrow",
            mods = "CTRL | SHIFT",
            -- Previous tab
            action = wezterm.action { ActivateTabRelative = -1 }
          },
          {
            key = "RightArrow",
            mods = "CTRL | SHIFT",
            -- Next tab
            action = wezterm.action { ActivateTabRelative = 1 }
          },
          {
            key = "j",
            mods = "CTRL | SHIFT",
            -- Scroll down
            action = wezterm.action { ScrollByLine = 1 }
          },
          {
            key = "k",
            mods = "CTRL | SHIFT",
            -- Scroll up
            action = wezterm.action { ScrollByLine = -1 }
          },
          {
            key = "h",
            mods = "CTRL | SHIFT",
            action = wezterm.action.SplitHorizontal { domain = "CurrentPaneDomain" },
          },
          {
            key = "v",
            mods = "CTRL | ALT",
            action = wezterm.action.SplitVertical { domain = "CurrentPaneDomain" },
          },
        }
       }
     '';
  };
}
