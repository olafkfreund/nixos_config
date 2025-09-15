{ config
, lib
, pkgs
, ...
}:
with lib; let
  cfg = config.desktop.rofi;

  # Simple waybar-matching theme - no boxes or borders
  gruvboxTheme = builtins.toFile "rofi-theme.rasi" ''
    /* Simple theme matching waybar */
    * {
      gruvbox-bg: #282828;
      gruvbox-fg: #ebdbb2;
      gruvbox-yellow: #fabd2f;
      transparent: #00000000;

      font: "JetBrainsMono Nerd Font 14";
      background-color: @gruvbox-bg;
      text-color: @gruvbox-fg;
    }

    element-text, element-icon {
      background-color: inherit;
      text-color: inherit;
    }

    window {
      width: 50%;
      background-color: @gruvbox-bg;
      border: none;
      border-radius: 0px;
      padding: 12px;
    }

    mainbox {
      background-color: @gruvbox-bg;
      spacing: 8px;
    }

    inputbar {
      children: [prompt, entry];
      background-color: @gruvbox-bg;
      border: none;
      border-radius: 0px;
      padding: 8px;
      margin: 0;
    }

    prompt {
      background-color: @gruvbox-bg;
      padding: 0px 8px 0px 0px;
      text-color: @gruvbox-yellow;
    }

    entry {
      padding: 0px;
      text-color: @gruvbox-fg;
      background-color: @gruvbox-bg;
      placeholder: "Search...";
    }

    listview {
      background-color: @gruvbox-bg;
      cycle: false;
      dynamic: true;
      layout: vertical;
      spacing: 0px;
      margin: 0;
      columns: 1;
      lines: 10;
      fixed-height: false;
    }

    element {
      padding: 8px;
      spacing: 8px;
      background-color: @gruvbox-bg;
      border: none;
      border-radius: 0px;
    }

    element normal.normal {
      background-color: @gruvbox-bg;
    }

    element alternate.normal {
      background-color: @gruvbox-bg;
    }

    element selected {
      background-color: @gruvbox-bg;
      text-color: @gruvbox-yellow;
    }

    element-icon {
      size: 18px;
      padding: 0 8px 0 0;
    }

    mode-switcher {
      spacing: 0px;
      background-color: @gruvbox-bg;
      border: none;
      border-radius: 0px;
      padding: 0px;
    }

    button {
      padding: 8px 12px;
      background-color: @gruvbox-bg;
      text-color: @gruvbox-fg;
      border: none;
      border-radius: 0px;
    }

    button selected {
      background-color: @gruvbox-bg;
      text-color: @gruvbox-yellow;
    }

    scrollbar {
      width: 0px;
      handle-width: 0px;
      handle-color: @transparent;
      background-color: @gruvbox-bg;
    }
  '';
in
{
  options.desktop.rofi = {
    enable = mkEnableOption "Rofi application launcher with Gruvbox theme";
  };

  config = mkIf cfg.enable {
    programs.rofi = {
      enable = true;
      package = pkgs.rofi;

      extraConfig = {
        modi = "drun,run,filebrowser";
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

      theme = lib.mkForce gruvboxTheme;

      plugins = with pkgs; [
        rofi-calc
        rofi-emoji
        rofi-file-browser
      ];
    };

    # Import our custom script
    home.packages = [
      #Rofi scripts
      (import ./scripts/websearch.nix { inherit pkgs; })
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

      # Override the custom theme file with our flat design
      ".local/share/rofi/themes/custom.rasi" = {
        text = ''
          /* Flat theme matching waybar - no boxes or borders */
          * {
              gruvbox-bg: #282828;
              gruvbox-fg: #ebdbb2;
              gruvbox-yellow: #fabd2f;
              transparent: #00000000;

              font: "JetBrainsMono Nerd Font 14";
              background-color: @gruvbox-bg;
              text-color: @gruvbox-fg;
          }

          element-text, element-icon {
              background-color: inherit;
              text-color: inherit;
          }

          window {
              width: 50%;
              background-color: @gruvbox-bg;
              border: none;
              border-radius: 0px;
              padding: 12px;
          }

          mainbox {
              background-color: @gruvbox-bg;
              spacing: 8px;
          }

          inputbar {
              children: [prompt, entry];
              background-color: @gruvbox-bg;
              border: none;
              border-radius: 0px;
              padding: 8px;
              margin: 0;
          }

          prompt {
              background-color: @gruvbox-bg;
              padding: 0px 8px 0px 0px;
              text-color: @gruvbox-yellow;
          }

          entry {
              padding: 0px;
              text-color: @gruvbox-fg;
              background-color: @gruvbox-bg;
              placeholder: "Search...";
          }

          listview {
              background-color: @gruvbox-bg;
              cycle: false;
              dynamic: true;
              layout: vertical;
              spacing: 0px;
              margin: 0;
              columns: 1;
              lines: 10;
              fixed-height: false;
              border: none;
          }

          element {
              padding: 8px;
              spacing: 8px;
              background-color: @gruvbox-bg;
              border: none;
              border-radius: 0px;
          }

          element normal.normal {
              background-color: @gruvbox-bg;
              text-color: @gruvbox-fg;
          }

          element alternate.normal {
              background-color: @gruvbox-bg;
              text-color: @gruvbox-fg;
          }

          element selected.normal {
              background-color: @gruvbox-bg;
              text-color: @gruvbox-yellow;
          }

          element normal.active {
              background-color: @gruvbox-bg;
              text-color: @gruvbox-fg;
          }

          element selected.active {
              background-color: @gruvbox-bg;
              text-color: @gruvbox-yellow;
          }

          element normal.urgent {
              background-color: @gruvbox-bg;
              text-color: @gruvbox-fg;
          }

          element selected.urgent {
              background-color: @gruvbox-bg;
              text-color: @gruvbox-yellow;
          }

          element alternate.active {
              background-color: @gruvbox-bg;
              text-color: @gruvbox-fg;
          }

          element alternate.urgent {
              background-color: @gruvbox-bg;
              text-color: @gruvbox-fg;
          }

          element-icon {
              size: 18px;
              padding: 0 8px 0 0;
              background-color: inherit;
              text-color: inherit;
          }

          mode-switcher {
              spacing: 0px;
              background-color: @gruvbox-bg;
              border: none;
              border-radius: 0px;
              padding: 0px;
          }

          button {
              padding: 8px 12px;
              background-color: @gruvbox-bg;
              text-color: @gruvbox-fg;
              border: none;
              border-radius: 0px;
          }

          button selected {
              background-color: @gruvbox-bg;
              text-color: @gruvbox-yellow;
          }

          scrollbar {
              width: 0px;
              handle-width: 0px;
              handle-color: @transparent;
              background-color: @gruvbox-bg;
          }

          message {
              background-color: @gruvbox-bg;
              border: none;
          }

          textbox {
              background-color: @gruvbox-bg;
              text-color: @gruvbox-fg;
          }

          sidebar {
              background-color: @gruvbox-bg;
              border: none;
          }

          case-indicator {
              background-color: @gruvbox-bg;
              text-color: @gruvbox-fg;
          }

          textbox-prompt-colon {
              background-color: @gruvbox-bg;
              text-color: @gruvbox-yellow;
          }
        '';
      };
    };
  };
}
