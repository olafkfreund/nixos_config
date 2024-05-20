{ pkgs, config, ... }:{
  
  programs.wezterm = {
    enable = true;
    package = pkgs.wezterm;
    extraConfig = ''
      -- +----------------------------+
      -- | WezTerm Configuration file |
      -- +----------------------------+

      local wezterm = require 'wezterm'

      local warn_about_missing_glyphs = false 

      local pad = 1

      local font_normal = {
      family = 'FiraCode Nerd Font',
      weight = 'Regular',
      italic = false
      }

      local font_italic = {
        family = 'VictorMono Nerd Font',
        weight = 'DemiBold',
        italic = true
      }

      function load_font(font)
        return wezterm.font(font.family, {
          weight = font.weight,
          italic = font.italic
        })
      end

      return {
        -- Window, layout
        window_background_opacity = 0.8,
        window_padding = {
          left = pad,
          right = pad,
          top = pad,
          bottom = pad
        },
        window_frame = {
          active_titlebar_bg = '#${config.colorScheme.palette.base04}',
          inactive_titlebar_bg = '#${config.colorScheme.palette.base00}'
        },
        hide_tab_bar_if_only_one_tab = true,
        use_fancy_tab_bar = true,
        warn_about_missing_glyphs = false,
        initial_cols = 100,
        initial_rows = 40,

        -- Fonts
        font = load_font(font_normal),
        font_size = 14,
        font_rules = {
          {
            italic = true,
            font = load_font(font_italic)
          }
        },

        -- Colors
        color_scheme = 'gruvbox',
        color_schemes = {
          gruvbox = {
            foreground = '#${config.colorScheme.palette.base06}',
            background = '#${config.colorScheme.palette.base00}',
            cursor_bg = '#${config.colorScheme.palette.base07}',
            cursor_border = '#${config.colorScheme.palette.base06}',
            cursor_fg = '#${config.colorScheme.palette.base00}',
            selection_bg = '#${config.colorScheme.palette.base02}',
            selection_fg = '#${config.colorScheme.palette.base01}',

            ansi = {
              '#${config.colorScheme.palette.base00}', -- black
              '#${config.colorScheme.palette.base08}', -- red
              '#${config.colorScheme.palette.base0B}', -- green
              '#${config.colorScheme.palette.base0A}', -- yellow
              '#${config.colorScheme.palette.base0D}', -- blue
              '#${config.colorScheme.palette.base0E}', -- purple
              '#${config.colorScheme.palette.base0C}', -- aqua
              '#${config.colorScheme.palette.base06}'  -- white
            },

            brights = {
              '#${config.colorScheme.palette.base00}', -- black
              '#${config.colorScheme.palette.base08}', -- red
              '#${config.colorScheme.palette.base0B}', -- green
              '#${config.colorScheme.palette.base0A}', -- yellow
              '#${config.colorScheme.palette.base0D}', -- blue
              '#${config.colorScheme.palette.base0E}', -- purple
              '#${config.colorScheme.palette.base0C}', -- aqua
              '#${config.colorScheme.palette.base06}'  -- white
            }
          }
        },

        -- Keybinds
        keys = {
          {
            key = 'LeftArrow',
            mods = 'CTRL | SHIFT',
            -- Previous tab
            action = wezterm.action { ActivateTabRelative = -1 }
          },
          {
            key = 'RightArrow',
            mods = 'CTRL | SHIFT',
            -- Next tab
            action = wezterm.action { ActivateTabRelative = 1 }
          },
          {
            key = 'j',
            mods = 'CTRL | SHIFT',
            -- Scroll down
            action = wezterm.action { ScrollByLine = 1 }
          },
          {
            key = 'k',
            mods = 'CTRL | SHIFT',
            -- Scroll up
            action = wezterm.action { ScrollByLine = -1 }
          },
          {
            key = 'h',
            mods = 'CTRL | SHIFT',
            action = wezterm.action.SplitHorizontal { domain = 'CurrentPaneDomain' },
          },
          {
            key = 'v',
            mods = 'CTRL | ALT',
            action = wezterm.action.SplitVertical { domain = 'CurrentPaneDomain' },
          },
        }
      }
    '';
  };
}
