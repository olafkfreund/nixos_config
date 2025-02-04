{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.desktop.rofi;
  theme = builtins.toFile "rofi-theme.rasi" ''
    element-text {
         background-color: #00000000;
         text-color: inherit;
     }

     element-text selected {
         background-color: #00000000;
         text-color: inherit;
     }

     mode-switcher {
         background-color: #00000000;
     }

     window {
         height: 100%;
         width: 40%;
         location: west;
         anchor: west;
         border: 0px;
         border-radius: 10px;
         border: 0px 0px 0px 0px;
         border-color: #ebdbb2;
         background-color: #282828;
         padding: 4px 8px 4px 8px;
         fullscreen: false;
     }

     mainbox {
         background-color: #00000000;
     }

     inputbar {
         children: [prompt,entry];
         background-color: #00000000;
         border-radius: 5px;
         padding: 2px;
         margin: 0px -5px -4px -5px;
         children: [ "prompt", "entry" ];
     }

     prompt {
         background-color: #282828;
         padding: 12px 12px 12px 12px;
         margin: 8px 8px 0px 8px;
         text-color: #ebdbb2;
     }

     textbox-prompt-colon {
         expand: false;
         str: "::";
     }

     entry {
         padding: 12px 12px 12px 12px;
         margin: 8px 8px 0px 8px;
         text-color: #ebdbb2;
         background-color: #282828;
         border-radius: 5px;
         border: 1px 1px 1px 1px;
         border-color: #504945;
     }

     listview {
         border: 0px 0px 0px;
         margin: 27px 5px -13px 5px;
         background-color: #00000000;
         columns: 2;
         lines: 25;
     }

     element {
         padding: 12px 12px 12px 12px;
         background-color: #282828;
         text-color: #ebdbb2;
         margin: 0px 0px 8px 0px;
     }

     mesg {
         padding: 12px;
         margin: 10px 5px 10px 5px;
         background-color: #1f2223;
         text-color: #689d6a;
         vertical-align: 0.5;
         horizontal-align: 0.5;
         border-radius: 5px;
         border: 0px 0px 8px 8px;
         border-color: #191c1d;
     }

     element-icon {
         size: 25px;
         background-color: #00000000;
     }

     element selected {
         background-color: #282828;
         text-color: #fabd2f;
     }

     mode-switcher {
         spacing: 0;
     }

     button {
         padding: 12px;
         margin: 10px 5px 10px 5px;
         background-color: #282828;
         text-color: #ebdbb2;
         vertical-align: 0.5;
         horizontal-align: 0.5;
         border-radius: 5px;
         border: 1px 1px 6px 6px;
         border-color: #504945;
     }

     button selected {
         background-color: #282828;
         text-color: #fabd2f;
         border-radius: 5px;
         border: 1px 1px 6px 6px;
         border-color: #504945;
     }
  '';
in {
  options.desktop.rofi = {
    enable = mkEnableOption {
      default = false;
      description = "rofi";
    };
  };
  config = mkIf cfg.enable {
    home.file = {
      ".config/rofi/rofi-powermenu-gruvbox-config.rasi".source = ../config/rofi/rofi-powermenu-gruvbox-config.rasi;
      ".config/rofi/rofi.rasi".source = ../config/rofi/rofi.rasi;
      ".config/rofi/gruvbox.rasi".source = ../config/rofi/gruvbox.rasi;
    };
    programs.rofi = {
      enable = true;
      package = pkgs.rofi-wayland;
      extraConfig = {
        modi = "run,ssh,filebrowser,keys,combi,drun,window";
        lines = 15;
        font = "JetBrains Mono Nerd Font Bold 14";
        show-icons = true;
        terminal = "foot";
        drun-display-format = "{icon} {name}";
        location = 0;
        disable-history = false;
        hide-scrollbar = true;
        sidebar-mode = true;
        display-drun = " 󰀘 Apps";
        display-run = " 󱄅 Command";
        display-filebrowser = " File Browser";
        display-window = "  Window";
        display-ssh = "  SSH";
        display-keys = " 󱕴 Keys";
      };
      theme = theme;
    };

    home.packages = with pkgs; [
      rofi-wayland
      rofimoji
      rofi-emoji
      rofi-power-menu
      rofi-top
      rofi-systemd
      rofi-bluetooth
      rofi-screenshot
      rofi-file-browser
      rofi-calc
      rofi-mpd
      rofi-obsidian
      todofi-sh
    ];
  };
}
