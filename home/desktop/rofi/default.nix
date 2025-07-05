# Enhanced Rofi Configuration with Theming and Feature Flags
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
  
  # Feature flags for Rofi
  cfg = {
    # Core features
    core = {
      enable = true;
      package = pkgs.rofi-wayland;  # Use Wayland version
    };
    
    # Available modes
    modes = {
      applications = true;      # drun mode
      commands = true;          # run mode
      files = true;            # file browser
      calculator = true;        # calculator
      emoji = true;            # emoji picker
      websearch = true;         # web search
      power = true;            # power menu
      bluetooth = false;        # bluetooth menu
    };
    
    # Visual features
    visual = {
      icons = true;
      animations = true;
      transparency = true;
      sidebar = true;
      thumbnails = true;
    };
    
    # Performance features
    performance = {
      fuzzyMatching = true;
      sorting = true;
      caching = true;
      lines = 10;
    };
  };
  
  # Color scheme definitions (matching other components)
  colorSchemes = {
    gruvbox-dark = {
      bg = "#282828";
      bg-light = "#3c3836";
      fg = "#ebdbb2";
      border = "#504945";
      accent = "#fabd2f";
      selected = "#689d6a";
      orange = "#fe8019";
      transparent = "#00000000";
    };
  };
  
  selectedTheme = hostVars.rofi.theme or "gruvbox-dark";
  activeColors = colorSchemes.${selectedTheme} or colorSchemes.gruvbox-dark;
  
  # Generate theme file
  generateTheme = colors: builtins.toFile "rofi-enhanced-theme.rasi" ''
    /* Enhanced Rofi Theme */
    * {
      bg: ${colors.bg};
      bg-light: ${colors.bg-light};
      fg: ${colors.fg};
      border: ${colors.border};
      accent: ${colors.accent};
      selected: ${colors.selected};
      orange: ${colors.orange};
      transparent: ${colors.transparent};

      font: "JetBrainsMono Nerd Font 13";
      background-color: @transparent;
      text-color: @fg;
    }

    element-text, element-icon {
      background-color: @transparent;
      text-color: inherit;
    }

    window {
      width: 50%;
      background-color: @bg;
      border: 1px;
      border-color: @border;
      border-radius: 8px;
      padding: 12px;
      ${optionalString cfg.visual.transparency "opacity: 0.98;"}
    }

    mainbox {
      background-color: @transparent;
      spacing: 12px;
    }

    inputbar {
      children: [prompt, entry];
      background-color: @bg;
      border-radius: 6px;
      padding: 4px 8px;
      margin: 0 0 8px 0;
      border: 1px;
      border-color: @border;
    }

    prompt {
      background-color: @transparent;
      padding: 6px;
      text-color: @orange;
      font-weight: bold;
    }

    entry {
      padding: 6px;
      text-color: @fg;
      background-color: @transparent;
      placeholder: "Search...";
      placeholder-color: @border;
    }

    listview {
      background-color: @transparent;
      cycle: false;
      dynamic: true;
      layout: vertical;
      spacing: 4px;
      margin: 0;
      columns: 1;
      lines: ${toString cfg.performance.lines};
      fixed-height: false;
      scrollbar: ${if cfg.visual.sidebar then "true" else "false"};
    }

    element {
      padding: 8px;
      spacing: 8px;
      background-color: @transparent;
      border-radius: 6px;
      ${optionalString cfg.visual.animations "transition: 200ms;"}
    }

    element normal.normal {
      background-color: @transparent;
    }

    element alternate.normal {
      background-color: @transparent;
    }

    element selected {
      background-color: @bg-light;
      text-color: @selected;
      border: 1px;
      border-color: @selected;
    }

    element-icon {
      size: 20px;
      padding: 0 8px 0 0;
    }

    mode-switcher {
      spacing: 6px;
      background-color: @bg;
      border-radius: 6px;
      padding: 6px;
      border: 1px;
      border-color: @border;
    }

    button {
      padding: 8px 12px;
      background-color: @transparent;
      text-color: @fg;
      border-radius: 4px;
    }

    button selected {
      background-color: @bg-light;
      text-color: @accent;
      border: 1px;
      border-color: @accent;
    }

    scrollbar {
      width: 6px;
      handle-width: 6px;
      handle-color: @border;
      background-color: @bg;
      border-radius: 3px;
    }

    message {
      background-color: @bg-light;
      border: 1px;
      border-color: @border;
      border-radius: 6px;
      padding: 8px;
      margin: 8px 0;
    }

    textbox {
      text-color: @fg;
      background-color: @transparent;
    }
  '';
  
  # Available modes configuration
  availableModes = 
    optional cfg.modes.applications "drun" ++
    optional cfg.modes.commands "run" ++
    optional cfg.modes.files "filebrowser" ++
    optional cfg.modes.calculator "calc" ++
    optional cfg.modes.emoji "emoji" ++
    optional cfg.modes.websearch "websearch:rwebsearch" ++
    optional cfg.modes.power "power-menu:rofi-power-menu" ++
    optional cfg.modes.bluetooth "bluetooth:rofi-bluetooth";
  
in {
  # Backward compatibility option structure
  options.desktop.rofi = {
    enable = mkEnableOption "Rofi application launcher with enhanced features";
  };
  
  config = {
    programs.rofi = mkIf (cfg.core.enable || config.desktop.rofi.enable) {
    enable = true;
    package = cfg.core.package;

    extraConfig = {
      # Available modes
      modi = concatStringsSep "," availableModes;
      
      # Appearance
      lines = cfg.performance.lines;
      font = "JetBrainsMono Nerd Font 14";
      show-icons = cfg.visual.icons;
      icon-theme = "Papirus-Dark";
      window-thumbnail = cfg.visual.thumbnails;
      
      # Terminal
      terminal = "foot";
      
      # Display format
      drun-display-format = if cfg.visual.icons then "{icon} {name}" else "{name}";
      
      # Layout
      location = 0;
      sidebar-mode = cfg.visual.sidebar;
      hide-scrollbar = !cfg.visual.sidebar;
      
      # Performance
      disable-history = !cfg.performance.caching;
      sort = cfg.performance.sorting;
      sorting-method = if cfg.performance.fuzzyMatching then "fzf" else "normal";
      matching = if cfg.performance.fuzzyMatching then "fuzzy" else "normal";
      cache-dir = mkIf cfg.performance.caching "~/.cache/rofi";
      
      # Display labels with icons
      display-drun = " 󰀘 Apps";
      display-run = " 󱄅 Run";
      display-filebrowser = " 󰉋 Files";
      display-calc = " 󰃬 Calc";
      display-emoji = " 󰞅 Emoji";
      display-websearch = " 󰖟 Search";
      display-power-menu = " 󰐥 Power";
      display-bluetooth = " 󰂯 Bluetooth";
      
      # Keybindings (vim-style)
      kb-row-up = "Up,Control+k";
      kb-row-down = "Down,Control+j";
      kb-accept-entry = "Return";
      kb-remove-to-eol = "";
      hover-select = true;
      
      # Advanced features
      run-shell-command = "{terminal} -e {cmd}";
      run-command = "{cmd}";
    };

    theme = mkDefault (generateTheme activeColors);

    plugins = with pkgs; 
      optional cfg.modes.calculator rofi-calc ++
      optional cfg.modes.emoji rofi-emoji ++
      optional cfg.modes.files rofi-file-browser ++
      optional cfg.modes.power rofi-power-menu ++
      optional cfg.modes.bluetooth rofi-bluetooth;
  };

    # Enhanced launcher scripts
    home.packages = with pkgs; [
      # Web search script (from existing config)
      (mkIf cfg.modes.websearch (import ./scripts/websearch.nix { inherit pkgs; }))
    ] ++ optionals (cfg.core.enable || config.desktop.rofi.enable) [
    # Additional rofi utilities
    rofi-systemd
  ];

  # Launcher scripts for different rofi modes
  home.file = mkMerge [
    # Web search launcher
    (mkIf cfg.modes.websearch {
      ".local/bin/rofi-websearch" = {
        text = ''
          #!/bin/sh
          rofi -show websearch
        '';
        executable = true;
      };
    })
    
    # Power menu launcher
    (mkIf cfg.modes.power {
      ".local/bin/rofi-power" = {
        text = ''
          #!/bin/sh
          rofi -show power-menu
        '';
        executable = true;
      };
    })
    
    # Calculator launcher
    (mkIf cfg.modes.calculator {
      ".local/bin/rofi-calc" = {
        text = ''
          #!/bin/sh
          rofi -show calc -modi calc -no-show-match -no-sort
        '';
        executable = true;
      };
    })
    
    # Emoji picker launcher
    (mkIf cfg.modes.emoji {
      ".local/bin/rofi-emoji" = {
        text = ''
          #!/bin/sh
          rofi -show emoji -modi emoji
        '';
        executable = true;
      };
    })
    
    # File browser launcher
    (mkIf cfg.modes.files {
      ".local/bin/rofi-files" = {
        text = ''
          #!/bin/sh
          rofi -show filebrowser -modi filebrowser
        '';
        executable = true;
      };
    })
    
    # Bluetooth launcher
    (mkIf cfg.modes.bluetooth {
      ".local/bin/rofi-bluetooth" = {
        text = ''
          #!/bin/sh
          rofi -show bluetooth
        '';
        executable = true;
      };
    })
    
    # Quick launcher with common modes
    (mkIf cfg.core.enable {
      ".local/bin/rofi-launcher" = {
        text = ''
          #!/bin/sh
          # Quick launcher with the most common modes
          rofi -show drun -modi drun,run${optionalString cfg.modes.files ",filebrowser"}${optionalString cfg.modes.calculator ",calc"}
        '';
        executable = true;
      };
    })
  ];

    # Ensure rofi can find plugins and scripts
    home.sessionVariables = mkIf (cfg.core.enable || config.desktop.rofi.enable) {
      ROFI_PLUGIN_PATH = "${config.programs.rofi.package}/lib/rofi";
    };
  };
}