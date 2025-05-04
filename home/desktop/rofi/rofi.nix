{
  config,
  lib,
  pkgs-unstable,
  ...
}:
with lib; let
  cfg = config.desktop.rofi;

  # Extract theme to separate variable for better maintainability
  gruvboxTheme = builtins.toFile "rofi-theme.rasi" ''
    /* Global Properties */
    * {
      gruvbox-bg: #282828;
      gruvbox-fg: #ebdbb2;
      gruvbox-yellow: #fabd2f;
      gruvbox-border: #504945;
      gruvbox-green: #689d6a;
      transparent: #00000000;

      font: "JetBrains Mono Nerd Font Bold 14";
      background-color: @transparent;
    }

    element-text {
      background-color: @transparent;
      text-color: inherit;
    }

    element-text selected {
      background-color: @transparent;
      text-color: inherit;
    }

    mode-switcher {
      background-color: @transparent;
    }

    window {
      height: 60%;
      width: 30%;
      location: center;
      anchor: center;
      border-radius: 10px;
      border: 0px;
      background-color: @gruvbox-bg;
      padding: 4px 8px;
    }

    mainbox {
      background-color: @transparent;
    }

    inputbar {
      children: [prompt, entry];
      background-color: @transparent;
      border-radius: 5px;
      padding: 2px;
      margin: 0px -5px -4px -5px;
    }

    prompt {
      background-color: @gruvbox-bg;
      padding: 12px;
      margin: 8px 8px 0px 8px;
      text-color: @gruvbox-fg;
    }

    entry {
      padding: 12px;
      margin: 8px 8px 0px 8px;
      text-color: @gruvbox-fg;
      background-color: @gruvbox-bg;
      border-radius: 5px;
      border: 1px;
      border-color: @gruvbox-border;
    }

    listview {
      border: 0px;
      margin: 27px 5px -13px 5px;
      background-color: @transparent;
      columns: 2;
      lines: 10;
      dynamic: true;
      fixed-height: false;
      scrollbar: true;
    }

    element {
      padding: 12px;
      background-color: @gruvbox-bg;
      text-color: @gruvbox-fg;
      margin: 0px 0px 8px 0px;
      border-radius: 5px;
    }

    element-icon {
      size: 25px;
      background-color: @transparent;
      padding: 0px 10px 0px 0px;
    }

    element selected {
      background-color: @gruvbox-bg;
      text-color: @gruvbox-yellow;
      border: 1px;
      border-color: @gruvbox-yellow;
    }

    mode-switcher {
      spacing: 0;
    }

    button {
      padding: 12px;
      margin: 10px 5px;
      background-color: @gruvbox-bg;
      text-color: @gruvbox-fg;
      vertical-align: 0.5;
      horizontal-align: 0.5;
      border-radius: 5px;
      border: 1px 1px 6px 6px;
      border-color: @gruvbox-border;
    }

    button selected {
      background-color: @gruvbox-bg;
      text-color: @gruvbox-yellow;
      border-color: @gruvbox-border;
    }

    scrollbar {
      width: 4px;
      handle-width: 8px;
      handle-color: @gruvbox-border;
    }
  '';
in {
  options.desktop.rofi = {
    enable = mkEnableOption "Rofi application launcher with Gruvbox theme";
  };

  config = mkIf cfg.enable {
    programs.rofi = {
      enable = true;
      package = pkgs-unstable.rofi-wayland;

      extraConfig = {
        modi = "drun,run,window,ssh,filebrowser,keys,calc";
        lines = 10;
        font = "JetBrains Mono Nerd Font Bold 14";
        show-icons = true;
        terminal = "foot";
        drun-display-format = "{icon} {name}";
        location = 0;
        disable-history = false;
        hide-scrollbar = false;
        sidebar-mode = true;

        # Better icon support
        icon-theme = "Papirus-Dark";

        # Display labels
        display-drun = " 󰀘 Apps";
        display-run = " 󱄅 Command";
        display-filebrowser = " Files";
        display-window = "   Window";
        display-ssh = " 󰣀  SSH";
        display-keys = " 󱕴 Keys";
        display-calc = "  Calculator";

        # Performance options
        sort = true;
        sorting-method = "fzf";
        matching = "fuzzy";
        cache-dir = "~/.cache/rofi";
        window-thumbnail = true;

        # Improved usability
        kb-row-up = "Up,Control+k";
        kb-row-down = "Down,Control+j";
        kb-accept-entry = "Return";
        kb-remove-to-eol = "";
        # kb-mode-next = "Tab";
        # kb-mode-previous = "ISO_Left_Tab";
        hover-select = true;
      };

      theme = gruvboxTheme;

      plugins = with pkgs-unstable; [
        rofi-calc
        rofi-emoji
        rofi-file-browser
      ];
    };

    # Install additional Rofi plugins but organize them better
    home.packages = with pkgs-unstable; [
      # Core plugins
      rofi-calc

      # System utilities
      rofi-power-menu
      rofi-bluetooth
      rofi-systemd

      # Media and files
      rofi-mpd
      rofi-file-browser

      # Messaging/social
      rofimoji
      rofi-emoji

      # Productivity
      rofi-screenshot
      rofi-obsidian
      todofi-sh

      # System monitoring
      rofi-top
    ];

    # Create launcher scripts for common rofi use cases
    home.file = {
      ".local/bin/rofi-power" = {
        text = ''
          #!/bin/sh
          rofi -show power-menu -modi power-menu:${pkgs-unstable.rofi-power-menu}/bin/rofi-power-menu
        '';
        executable = true;
      };

      ".local/bin/rofi-bluetooth" = {
        text = ''
          #!/bin/sh
          ${pkgs-unstable.rofi-bluetooth}/bin/rofi-bluetooth
        '';
        executable = true;
      };
    };
  };
}
