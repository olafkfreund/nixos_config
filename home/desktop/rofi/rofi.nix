{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.desktop.rofi;

  # Extract theme to separate variable for better maintainability
  gruvboxTheme = builtins.toFile "rofi-theme.rasi" ''
    /* Global Properties */
    * {
      gruvbox-bg: #282828;
      gruvbox-bg-light: #3c3836;
      gruvbox-fg: #ebdbb2;
      gruvbox-yellow: #fabd2f;
      gruvbox-border: #504945;
      gruvbox-green: #689d6a;
      transparent: #00000000;
      gruvbox-orange: #fe8019;

      font: "JetBrainsMono Nerd Font 13";
      background-color: @transparent;
      text-color: @gruvbox-fg;
    }

    element-text, element-icon {
      background-color: @transparent;
      text-color: inherit;
    }

    window {
      width: 50%;
      background-color: @gruvbox-bg;
      border: 1px;
      border-color: @gruvbox-border;
      border-radius: 6px;
      padding: 12px;
    }

    mainbox {
      background-color: @transparent;
      spacing: 12px;
    }

    inputbar {
      children: [prompt, entry];
      background-color: @gruvbox-bg;
      border-radius: 6px;
      padding: 4px 8px;
      margin: 0 0 8px 0;
    }

    prompt {
      background-color: @transparent;
      padding: 6px;
      text-color: @gruvbox-orange;
    }

    entry {
      padding: 6px;
      text-color: @gruvbox-fg;
      background-color: @transparent;
      placeholder: "Search...";
    }

    listview {
      background-color: @transparent;
      cycle: false;
      dynamic: true;
      layout: vertical;
      spacing: 6px;
      margin: 0;
      columns: 1;
      lines: 10;
      fixed-height: false;
    }

    element {
      padding: 8px;
      spacing: 8px;
      background-color: @transparent;
      border-radius: 4px;
    }

    element normal.normal {
      background-color: @transparent;
    }

    element alternate.normal {
      background-color: @transparent;
    }

    element selected {
      background-color: @gruvbox-bg-light;
      text-color: @gruvbox-green;
    }

    element-icon {
      size: 18px;
      padding: 0 8px 0 0;
    }

    mode-switcher {
      spacing: 6px;
      background-color: @gruvbox-bg;
      border-radius: 4px;
      padding: 4px;
    }

    button {
      padding: 6px 12px;
      background-color: @transparent;
      text-color: @gruvbox-fg;
      border-radius: 4px;
    }

    button selected {
      background-color: @gruvbox-bg-light;
      text-color: @gruvbox-yellow;
    }

    scrollbar {
      width: 4px;
      handle-width: 4px;
      handle-color: @gruvbox-border;
      background-color: @gruvbox-bg;
    }
  '';
in {
  options.desktop.rofi = {
    enable = mkEnableOption "Rofi application launcher with Gruvbox theme";
  };

  config = mkIf cfg.enable {
    programs.rofi = {
      enable = true;
      package = pkgs.rofi-wayland;

      extraConfig = {
        modi = "drun,run,filebrowser,websearch:rwebsearch";
        lines = 10;
        font = "JetBrainsMono Nerd Font 14";
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
        display-filebrowser = " Files";
        # display-websearch = " 󰖟 Search";

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

      plugins = with pkgs; [
        rofi-calc
        rofi-emoji
        rofi-file-browser
      ];
    };

    # Import our custom script
    home.packages = [
      #Rofi scripts
      (import ./scripts/websearch.nix {inherit pkgs;})
    ];

    # Create launcher scripts for common rofi use cases and for websearch
    home.file = {
      ".local/bin/rwebsearch-launcher" = {
        text = ''
          #!/bin/sh
          rwebsearch
        '';
        executable = true;
      };

      ".local/bin/rofi-power" = {
        text = ''
          #!/bin/sh
          rofi -show power-menu -modi power-menu:${pkgs.rofi-power-menu}/bin/rofi-power-menu
        '';
        executable = true;
      };

      ".local/bin/rofi-bluetooth" = {
        text = ''
          #!/bin/sh
          ${pkgs.rofi-bluetooth}/bin/rofi-bluetooth
        '';
        executable = true;
      };
    };
  };
}
