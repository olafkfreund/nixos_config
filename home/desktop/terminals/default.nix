# Enhanced Terminal Configuration with Unified Theming and Feature Flags
{ lib
, pkgs
, ...
}:
let
  inherit (lib) mkIf mkEnableOption mkDefault optionals optionalString;
  vars = import ../../../hosts/common/shared-variables.nix;

  # Terminal feature flags
  cfg = {
    # Available terminals
    terminals = {
      foot = true; # Lightweight Wayland terminal
      kitty = true; # GPU-accelerated terminal
      alacritty = true; # Cross-platform terminal
      wezterm = false; # Rust-based terminal
      ghostty = false; # Fast terminal emulator
    };

    # Features
    features = {
      fontLigatures = true; # Enable font ligatures
      nerdFont = true; # Use Nerd Font symbols
      transparency = false; # Background transparency
      animations = true; # Terminal animations
      shellIntegration = true; # Shell integration features
      mouseSupport = true; # Mouse support
      urlDetection = true; # URL detection and opening
      copyOnSelect = true; # Copy on selection
      scrollback = 100000; # Scrollback lines
    };

    # Performance settings
    performance = {
      repaintDelay = 7; # Milliseconds
      inputDelay = 1; # Milliseconds
      enableVsync = true; # VSync for smooth rendering
    };
  };

  # No colour table here: Stylix owns every terminal's palette (base16Scheme in
  # hosts/common/shared-variables.nix). A hardcoded gruvbox table used to live
  # here — it was dead for foot/alacritty (Stylix outranked it) but silently WON
  # for kitty, which is why kitty stayed gruvbox after the Alien HUD swap while
  # every other terminal changed. Re-add per-terminal colours only to override
  # Stylix deliberately, never as a "default".

  # Common keybindings across terminals
  commonKeybinds = {
    copy = "Control+Shift+c";
    paste = "Control+Shift+v";
    fontIncrease = "Control+Shift+equal";
    fontDecrease = "Control+Shift+minus";
    fontReset = "Control+Shift+0";
    newTab = "Control+Shift+t";
    closeTab = "Control+Shift+q";
    nextTab = "Control+Shift+Right";
    prevTab = "Control+Shift+Left";
  };

  # Font configuration
  fontConfig = {
    name = "JetBrainsMono Nerd Font";
    size = 12;
    features = optionals cfg.features.fontLigatures [
      "liga"
      "clig"
      "calt"
    ];
  };
in
{
  imports = [
    ./ghostty
    ./wezterm
    ./warp
    ./wave
  ];

  # Backward compatibility options for individual terminals
  options = {
    alacritty.enable = mkEnableOption "Alacritty terminal (legacy compatibility)";
    foot.enable = mkEnableOption "Foot terminal (legacy compatibility)";
    kitty.enable = mkEnableOption "Kitty terminal (legacy compatibility)";
    # wezterm and ghostty options are defined in their respective imported modules
  };

  config = {
    programs = {
      # Foot terminal configuration
      foot = mkIf cfg.terminals.foot {
        enable = true;
        package = pkgs.foot;
        settings = {
          main = {
            pad = "12x12";
            term = "xterm-256color";
            selection-target = mkIf cfg.features.copyOnSelect "clipboard";
            shell = "${pkgs.zsh}/bin/zsh";
            font = mkDefault "${fontConfig.name}:size=${toString fontConfig.size}";
          };

          mouse-bindings = mkIf cfg.features.mouseSupport {
            primary-paste = "BTN_MIDDLE";
            select-begin = "BTN_LEFT";
            select-begin-block = "Control+BTN_LEFT";
            select-word = "BTN_LEFT-2";
            select-word-whitespace = "Control+BTN_LEFT-2";
          };

          key-bindings = {
            scrollback-up-page = "Shift+Page_Up";
            scrollback-down-page = "Shift+Page_Down";
            clipboard-copy = commonKeybinds.copy;
            clipboard-paste = commonKeybinds.paste;
            font-increase = commonKeybinds.fontIncrease;
            font-decrease = commonKeybinds.fontDecrease;
            font-reset = commonKeybinds.fontReset;
          };

          search-bindings = {
            cancel = "Control+g Control+c Escape";
            find-prev = "Control+r";
            find-next = "Control+s";
          };

          # No [colors] block: foot deprecated it in favour of [colors-dark],
          # which Stylix already writes (with alpha + indices 16-21). Setting
          # both emitted a deprecation warning per foot launch, and [colors]
          # lost to [colors-dark] anyway since initial-color-theme=dark.

          scrollback = {
            lines = cfg.features.scrollback;
          };
        };
      };

      # Kitty terminal configuration
      kitty = mkIf cfg.terminals.kitty {
        enable = true;
        package = pkgs.kitty;

        settings = {
          # Performance
          input_delay = cfg.performance.inputDelay;
          repaint_delay = cfg.performance.repaintDelay;
          sync_to_monitor = cfg.performance.enableVsync;

          # Appearance — keep native GNOME window decorations so the window
          # has a titlebar + min/max/close buttons. Previously this was
          # `true` which left Kitty borderless and hard to manage in GNOME.
          window_margin_width = 8;
          hide_window_decorations = false;
          # Theme the CSD titlebar to the terminal background (Stylix gruvbox)
          # instead of the default white "system" colour. Applies wherever Kitty
          # draws its own decorations (GNOME, and niri/labwc for clients that
          # ignore prefer-no-csd).
          wayland_titlebar_color = "background";
          placement_strategy = "center";
          # Same Weyland-Yutani plate as ghostty. Kitty has no opacity knob for
          # it — background_tint fades the image toward the background colour
          # instead, so 0.98 is the "almost invisible" equivalent of ghostty's
          # background-image-opacity = 0.02. foot and alacritty are absent here
          # because neither supports background images at all; they get the
          # palette from Stylix and nothing more.
          background_image = "${vars.baseTheme.terminalPlate}";
          background_image_layout = "scaled";
          background_tint = 0.98;
          background_opacity = mkDefault (
            if cfg.features.transparency
            then 0.95
            else 1.0
          );

          # Font
          font_family = mkDefault (
            if cfg.features.nerdFont
            then fontConfig.name
            else "monospace"
          );
          font_size = mkDefault fontConfig.size;
          disable_ligatures = mkDefault (
            if cfg.features.fontLigatures
            then "never"
            else "always"
          );

          # Behavior
          copy_on_select = mkDefault (
            if cfg.features.copyOnSelect
            then "yes"
            else "no"
          );
          mouse_hide_wait = mkDefault (
            if cfg.features.mouseSupport
            then 20
            else -1
          );
          scrollback_lines = mkDefault cfg.features.scrollback;

          # Terminal
          term = "xterm-kitty";
          shell = "${pkgs.zsh}/bin/zsh";

          # URLs
          detect_urls = mkDefault (
            if cfg.features.urlDetection
            then "yes"
            else "no"
          );
          url_style = "curly";

          # Cursor
          cursor_shape = "beam";
          cursor_blink_interval = mkDefault (
            if cfg.features.animations
            then 1
            else 0
          );
          cursor_stop_blinking_after = 15;

          # Tabs
          tab_bar_edge = "top";
          tab_bar_style = "powerline";
          tab_powerline_style = "round";
          tab_activity_symbol = "󰗖 ";
          active_tab_font_style = "bold";
          inactive_tab_font_style = "italic";
        };

        keybindings = {
          "${commonKeybinds.copy}" = "copy_to_clipboard";
          "${commonKeybinds.paste}" = "paste_from_clipboard";
          "${commonKeybinds.fontIncrease}" = "increase_font_size";
          "${commonKeybinds.fontDecrease}" = "decrease_font_size";
          "${commonKeybinds.fontReset}" = "restore_font_size";
          "${commonKeybinds.newTab}" = "new_tab";
          "${commonKeybinds.closeTab}" = "close_tab";
          "${commonKeybinds.nextTab}" = "next_tab";
          "${commonKeybinds.prevTab}" = "previous_tab";
          "ctrl+shift+enter" = "new_window";
          "ctrl+shift+l" = "next_layout";
          "ctrl+shift+f" = "show_scrollback";
        };

        extraConfig =
          optionalString cfg.features.nerdFont ''
            # Nerd Font symbol mappings
            symbol_map U+e000-U+e00a,U+ea60-U+ebeb,U+e0a0-U+e0c8,U+e0ca,U+e0cc-U+e0d4,U+e200-U+e2a9,U+e300-U+e3e3,U+e5fa-U+e6b1,U+e700-U+e7c5,U+f000-U+f2e0,U+f300-U+f372,U+f400-U+f532,U+f0001-U+f1af0 Symbols Nerd Font Mono
            symbol_map U+2600-U+26FF Noto Color Emoji
          ''
          + optionalString cfg.features.mouseSupport ''

            # Mouse mappings
            mouse_map left press ungrabbed mouse_selection normal
            mouse_map left doublepress ungrabbed mouse_selection word
            mouse_map left triplepress ungrabbed mouse_selection line
            mouse_map right press ungrabbed mouse_paste
            mouse_map middle release ungrabbed paste_from_selection
          '';

        shellIntegration = mkIf cfg.features.shellIntegration {
          enableZshIntegration = true;
          enableBashIntegration = true;
        };
      };

      # Alacritty terminal configuration
      alacritty = mkIf cfg.terminals.alacritty {
        enable = true;
        package = pkgs.alacritty;

        settings = {
          # Terminal configuration
          terminal.shell = {
            program = "${pkgs.zsh}/bin/zsh";
          };

          # Window configuration
          window = {
            padding = {
              x = 12;
              y = 12;
            };
            opacity = mkIf cfg.features.transparency 0.95;
            decorations = "none";
          };

          # Font configuration
          font = mkDefault {
            normal = {
              family = fontConfig.name;
              style = "Regular";
            };
            bold = {
              family = fontConfig.name;
              style = "Bold";
            };
            italic = {
              family = fontConfig.name;
              style = "Italic";
            };
            inherit (fontConfig) size;
          };


          # Scrolling
          scrolling = {
            history = cfg.features.scrollback;
          };

          # Selection
          selection = {
            save_to_clipboard = cfg.features.copyOnSelect;
          };

          # Mouse
          mouse = mkIf cfg.features.mouseSupport {
            hide_when_typing = true;
          };

          # Keyboard bindings
          keyboard.bindings = [
            {
              key = "C";
              mods = "Control|Shift";
              action = "Copy";
            }
            {
              key = "V";
              mods = "Control|Shift";
              action = "Paste";
            }
            {
              key = "Plus";
              mods = "Control|Shift";
              action = "IncreaseFontSize";
            }
            {
              key = "Minus";
              mods = "Control|Shift";
              action = "DecreaseFontSize";
            }
            {
              key = "Backspace";
              mods = "Control|Shift";
              action = "ResetFontSize";
            }
          ];
        };
      };
    };

    # Set default terminal
    xdg.mimeApps = {
      associations.added = {
        "x-scheme-handler/terminal" =
          if cfg.terminals.kitty
          then "kitty.desktop"
          else if cfg.terminals.foot
          then "foot.desktop"
          else if cfg.terminals.alacritty
          then "Alacritty.desktop"
          else "foot.desktop";
      };
      defaultApplications = {
        "x-scheme-handler/terminal" =
          if cfg.terminals.kitty
          then "kitty.desktop"
          else if cfg.terminals.foot
          then "foot.desktop"
          else if cfg.terminals.alacritty
          then "Alacritty.desktop"
          else "foot.desktop";
      };
    };

    # Terminal utilities
    home.packages = with pkgs;
      [
        # Terminal multiplexers
        tmux
        zellij

        # Terminal utilities
        btop # System monitor
        fastfetch # System info

        # File managers
        lf # Terminal file manager
        yazi # Modern terminal file manager
      ]
      ++ optionals cfg.features.nerdFont [
        # Nerd fonts
        nerd-fonts.jetbrains-mono
      ];
  };
}
