# Enhanced Terminal Configuration with Unified Theming and Feature Flags
{
  config,
  lib,
  pkgs,
  host ? "default",
  ...
}:
with lib;
let
  # Import host-specific variables if available
  hostVars = 
    if builtins.pathExists ../../../hosts/${host}/variables.nix
    then import ../../../hosts/${host}/variables.nix
    else {};
  
  # Terminal feature flags
  cfg = {
    # Available terminals
    terminals = {
      foot = true;           # Lightweight Wayland terminal
      kitty = true;          # GPU-accelerated terminal
      alacritty = false;     # Cross-platform terminal
      wezterm = false;       # Rust-based terminal
      ghostty = false;       # Fast terminal emulator
    };
    
    # Features
    features = {
      fontLigatures = true;         # Enable font ligatures
      nerdFont = true;              # Use Nerd Font symbols
      transparency = false;         # Background transparency
      animations = true;            # Terminal animations
      shellIntegration = true;      # Shell integration features
      mouseSupport = true;          # Mouse support
      urlDetection = true;          # URL detection and opening
      copyOnSelect = true;          # Copy on selection
      scrollback = 100000;          # Scrollback lines
    };
    
    # Performance settings
    performance = {
      repaintDelay = 7;            # Milliseconds
      inputDelay = 1;              # Milliseconds
      enableVsync = true;          # VSync for smooth rendering
    };
  };
  
  # Unified color scheme (compatible with existing stylix)
  terminalColors = {
    gruvbox-dark = {
      foreground = "ebdbb2";
      background = "282828";
      cursor = "ebdbb2";
      
      # Normal colors (0-7)
      black = "282828";
      red = "cc241d";
      green = "98971a";
      yellow = "d79921";
      blue = "458588";
      magenta = "b16286";
      cyan = "689d6a";
      white = "a89984";
      
      # Bright colors (8-15)
      bright_black = "928374";
      bright_red = "fb4934";
      bright_green = "b8bb26";
      bright_yellow = "fabd2f";
      bright_blue = "83a598";
      bright_magenta = "d3869b";
      bright_cyan = "8ec07c";
      bright_white = "ebdbb2";
    };
  };
  
  selectedTheme = hostVars.terminal.theme or "gruvbox-dark";
  activeColors = terminalColors.${selectedTheme} or terminalColors.gruvbox-dark;
  
  # Common keybindings across terminals
  commonKeybinds = {
    copy = "ctrl+shift+c";
    paste = "ctrl+shift+v";
    fontIncrease = "ctrl+shift+equal";
    fontDecrease = "ctrl+shift+minus";
    fontReset = "ctrl+shift+backspace";
    newTab = "ctrl+shift+t";
    closeTab = "ctrl+shift+q";
    nextTab = "ctrl+shift+right";
    prevTab = "ctrl+shift+left";
  };
  
  # Font configuration
  fontConfig = {
    name = "JetBrainsMono Nerd Font";
    size = 12;
    features = optionals cfg.features.fontLigatures [
      "liga" "clig" "calt"
    ];
  };
  
in {
  # Foot terminal configuration
  programs.foot = mkIf cfg.terminals.foot {
    enable = true;
    package = pkgs.foot;
    settings = {
      main = {
        pad = "12x12";
        term = "xterm-256color";
        selection-target = mkIf cfg.features.copyOnSelect "clipboard";
        shell = "${pkgs.zsh}/bin/zsh";
        font = mkIf cfg.features.nerdFont "${fontConfig.name}:size=${toString fontConfig.size}";
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
      
      colors = {
        foreground = activeColors.foreground;
        background = activeColors.background;
        regular0 = activeColors.black;
        regular1 = activeColors.red;
        regular2 = activeColors.green;
        regular3 = activeColors.yellow;
        regular4 = activeColors.blue;
        regular5 = activeColors.magenta;
        regular6 = activeColors.cyan;
        regular7 = activeColors.white;
        bright0 = activeColors.bright_black;
        bright1 = activeColors.bright_red;
        bright2 = activeColors.bright_green;
        bright3 = activeColors.bright_yellow;
        bright4 = activeColors.bright_blue;
        bright5 = activeColors.bright_magenta;
        bright6 = activeColors.bright_cyan;
        bright7 = activeColors.bright_white;
      };
      
      scrollback = {
        lines = cfg.features.scrollback;
      };
    };
  };
  
  # Kitty terminal configuration
  programs.kitty = mkIf cfg.terminals.kitty {
    enable = true;
    package = pkgs.kitty;
    
    settings = {
      # Performance
      input_delay = cfg.performance.inputDelay;
      repaint_delay = cfg.performance.repaintDelay;
      sync_to_monitor = cfg.performance.enableVsync;
      
      # Appearance
      window_margin_width = 8;
      hide_window_decorations = true;
      background_opacity = mkIf cfg.features.transparency 0.95;
      
      # Font
      font_family = mkIf cfg.features.nerdFont fontConfig.name;
      font_size = fontConfig.size;
      disable_ligatures = mkIf (!cfg.features.fontLigatures) "always";
      
      # Behavior
      copy_on_select = mkIf cfg.features.copyOnSelect "yes";
      mouse_hide_wait = mkIf cfg.features.mouseSupport 20;
      scrollback_lines = cfg.features.scrollback;
      
      # Terminal
      term = "xterm-kitty";
      shell = "${pkgs.zsh}/bin/zsh";
      
      # URLs
      detect_urls = mkIf cfg.features.urlDetection "yes";
      url_style = "curly";
      
      # Cursor
      cursor_shape = "beam";
      cursor_blink_interval = mkIf cfg.features.animations 1;
      cursor_stop_blinking_after = 15;
      
      # Tabs
      tab_bar_edge = "top";
      tab_bar_style = "powerline";
      tab_powerline_style = "round";
      tab_activity_symbol = "󰗖 ";
      active_tab_font_style = "bold";
      inactive_tab_font_style = "italic";
      
      # Colors
      foreground = "#${activeColors.foreground}";
      background = "#${activeColors.background}";
      cursor = "#${activeColors.cursor}";
      color0 = "#${activeColors.black}";
      color1 = "#${activeColors.red}";
      color2 = "#${activeColors.green}";
      color3 = "#${activeColors.yellow}";
      color4 = "#${activeColors.blue}";
      color5 = "#${activeColors.magenta}";
      color6 = "#${activeColors.cyan}";
      color7 = "#${activeColors.white}";
      color8 = "#${activeColors.bright_black}";
      color9 = "#${activeColors.bright_red}";
      color10 = "#${activeColors.bright_green}";
      color11 = "#${activeColors.bright_yellow}";
      color12 = "#${activeColors.bright_blue}";
      color13 = "#${activeColors.bright_magenta}";
      color14 = "#${activeColors.bright_cyan}";
      color15 = "#${activeColors.bright_white}";
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
    
    extraConfig = mkIf cfg.features.nerdFont ''
      # Nerd Font symbol mappings
      symbol_map U+e000-U+e00a,U+ea60-U+ebeb,U+e0a0-U+e0c8,U+e0ca,U+e0cc-U+e0d4,U+e200-U+e2a9,U+e300-U+e3e3,U+e5fa-U+e6b1,U+e700-U+e7c5,U+f000-U+f2e0,U+f300-U+f372,U+f400-U+f532,U+f0001-U+f1af0 Symbols Nerd Font Mono
      symbol_map U+2600-U+26FF Noto Color Emoji
    '' + optionalString cfg.features.mouseSupport ''
      
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
  
  # Set default terminal
  xdg.mimeApps = {
    associations.added = {
      "x-scheme-handler/terminal" = 
        if cfg.terminals.kitty then "kitty.desktop"
        else if cfg.terminals.foot then "foot.desktop"
        else "foot.desktop";
    };
    defaultApplications = {
      "x-scheme-handler/terminal" = 
        if cfg.terminals.kitty then "kitty.desktop"
        else if cfg.terminals.foot then "foot.desktop"
        else "foot.desktop";
    };
  };
  
  # Terminal utilities
  home.packages = with pkgs; [
    # Terminal multiplexers
    tmux
    zellij
    
    # Terminal utilities
    btop          # System monitor
    neofetch      # System info
    fastfetch     # Fast system info
    
    # File managers
    lf            # Terminal file manager
    yazi          # Modern terminal file manager
  ] ++ optionals cfg.features.nerdFont [
    # Nerd fonts
    (nerdfonts.override { fonts = [ "JetBrainsMono" ]; })
  ];
}