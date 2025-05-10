{
  pkgs,
  config,
  lib,
  ...
}:
with lib; let
  cfg = config.wezterm;
in {
  options.wezterm = {
    enable = mkEnableOption "WezTerm terminal emulator";
  };

  config = mkIf cfg.enable {
    xdg.mimeApps = {
      associations.added = {
        "x-scheme-handler/terminal" = "org.wezfurlong.wezterm.desktop";
      };
      defaultApplications = {
        "x-scheme-handler/terminal" = "org.wezfurlong.wezterm.desktop";
      };
    };

    programs.wezterm = {
      enable = true;
      package = pkgs.wezterm;

      # Shell integration
      enableBashIntegration = true;
      enableZshIntegration = true;

      # Configuration using Lua
      extraConfig = ''
        local wezterm = require 'wezterm'
        local act = wezterm.action
        local config = {}

        -- Appearance
        config.color_scheme = 'Gruvbox dark, medium (base16)'
        config.font = wezterm.font_with_fallback {
          'JetBrainsMono Nerd Font',
          'Noto Color Emoji',
        }
        config.font_size = 11.0
        config.window_padding = {
          left = 8,
          right = 8,
          top = 8,
          bottom = 8,
        }
        config.window_background_opacity = 0.95
        config.hide_tab_bar_if_only_one_tab = true
        config.use_fancy_tab_bar = false
        config.tab_bar_at_bottom = false
        config.window_decorations = "RESIZE"

        -- Behavior
        config.scrollback_lines = 10000
        config.enable_scroll_bar = false
        config.exit_behavior = 'Close'
        config.cursor_blink_rate = 800
        config.default_cursor_style = 'BlinkingBar'

        -- Key bindings
        config.keys = {
          -- Tab navigation
          {
            key = "LeftArrow",
            mods = "CTRL | SHIFT",
            action = act.ActivateTabRelative(-1),
          },
          {
            key = "RightArrow",
            mods = "CTRL | SHIFT",
            action = act.ActivateTabRelative(1),
          },

          -- Scrolling
          {
            key = "j",
            mods = "CTRL | SHIFT",
            action = act.ScrollByLine(1),
          },
          {
            key = "k",
            mods = "CTRL | SHIFT",
            action = act.ScrollByLine(-1),
          },

          -- Splits
          {
            key = "_",
            mods = "CTRL | SHIFT",
            action = act.SplitHorizontal { domain = "CurrentPaneDomain" },
          },
          {
            key = "|",
            mods = "CTRL | ALT",
            action = act.SplitVertical { domain = "CurrentPaneDomain" },
          },

          -- Navigation between panes
          {
            key = "h",
            mods = "ALT | SHIFT",
            action = act.ActivatePaneDirection "Left",
          },
          {
            key = "l",
            mods = "ALT | SHIFT",
            action = act.ActivatePaneDirection "Right",
          },
          {
            key = "k",
            mods = "ALT | SHIFT",
            action = act.ActivatePaneDirection "Up",
          },
          {
            key = "j",
            mods = "ALT | SHIFT",
            action = act.ActivatePaneDirection "Down",
          },

          -- Clipboard
          {
            key = "v",
            mods = "CTRL",
            action = act.PasteFrom "Clipboard",
          },
          {
            key = "c",
            mods = "CTRL",
            action = act.CopyTo "ClipboardAndPrimarySelection",
          },

          -- Font size
          {
            key = "=",
            mods = "CTRL",
            action = act.IncreaseFontSize,
          },
          {
            key = "-",
            mods = "CTRL",
            action = act.DecreaseFontSize,
          },
          {
            key = "0",
            mods = "CTRL",
            action = act.ResetFontSize,
          },

          -- New tab
          {
            key = "t",
            mods = "CTRL | SHIFT",
            action = act.SpawnTab "DefaultDomain",
          },
        }

        -- GPU acceleration settings
        config.webgpu_power_preference = "HighPerformance"
        config.animation_fps = 60

        -- Wayland-specific settings for Hyprland
        if wezterm.target_triple == 'x86_64-unknown-linux-gnu' then
          -- Detect Wayland
          local wayland = os.getenv("WAYLAND_DISPLAY") ~= nil or
                          os.getenv("XDG_SESSION_TYPE") == "wayland" or
                          os.getenv("NIXOS_WAYLAND") == "1"

          if wayland then
            config.enable_wayland = true

            -- Wayland-specific optimizations
            config.webgpu_preferred_adapter = config.webgpu_preferred_adapter or wezterm.default_webgpu_adapter()
            config.front_end = "WebGpu"  -- Better performance on modern systems with Wayland
            config.enable_wayland_ime = true  -- Improved input method support

            -- Fix clipboard issues on Wayland
            config.selection_word_boundary = " \t\n{}[]()\"'`,;:"

            -- Use native Wayland decorations when available
            config.window_decorations = "RESIZE"

            -- DPI handling (let Wayland handle this)
            config.adjust_window_size_when_changing_font_size = false
            config.pane_focus_follows_mouse = false

            -- Better integration with system theme
            local success, result = pcall(function()
              local handle = io.popen("gsettings get org.gnome.desktop.interface gtk-theme 2>/dev/null")
              if handle then
                local output = handle:read("*a")
                handle:close()
                return output:match("'(.-)'")
              end
              return nil
            end)

            local theme = success and result or nil
            if theme and theme:match("Gruvbox") then
              -- Already using Gruvbox, no need to change color scheme
            end
          end
        end

        return config
      '';
    };
  };
}
