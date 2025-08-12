{ pkgs
, config
, lib
, ...
}:
with lib; let
  cfg = config.desktop.walker;
in
{
  options.desktop.walker = {
    enable = mkEnableOption {
      default = false;
      description = "Enable Walker launcher";
    };

    runAsService = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to run Walker as a background service for faster startup";
    };
  };

  config = mkIf cfg.enable {
    programs.walker = {
      enable = true;
      package = pkgs.walker;
      inherit (cfg) runAsService;

      # Configuration options for Walker
      config = {
        search.placeholder = "Search...";
        ui = {
          fullscreen = false;
          anchors = {
            left = false;
            right = false;
            top = false;
            bottom = false;
          };
          margins = {
            top = 20;
            bottom = 20;
            left = 20;
            right = 20;
          };
          width = 1000;
          height = 800;
          icon_theme = "Adwaita";
          icon_size = 26;
          show_search = true;
        };
        list = {
          height = 650;
          width = 960;
          margin = 20;
        };
        hotreload_theme = false;
        builtins.windows.weight = 100;
        builtins.clipboard = {
          prefix = ''"'';
          always_put_new_on_top = true;
        };
        activation_mode.disabled = true;
        ignore_mouse = true;
        websearch.prefix = "?";
        switcher.prefix = "/";
        theme = "gruvbox";

        # Enable and configure Walker modules
        modules = {
          # Core modules
          applications = {
            enable = true;
            # Filter out desktop entries with empty exec lines
            filter = "true"; # Default filter
            fuzzy = true; # Enable fuzzy matching
            show_icons = true; # Show application icons
          };
          calculator.enable = true;
          runner.enable = true;
          clipboard = {
            enable = true;
            # Always put new clipboard entries at the top
            always_put_new_on_top = true;
          };

          # Web and search modules
          websearch = {
            enable = true;
            # Custom search engines
            entries = [
              {
                name = "GitHub";
                url = "https://github.com/search?q=%s";
                prefix = "gh";
              }
              {
                name = "NixOS Packages";
                url = "https://search.nixos.org/packages?query=%s";
                prefix = "nix";
              }
            ];
          };

          # System and window management
          windows.enable = true;
          switcher.enable = true;

          # Development tools
          ssh.enable = true;
          commands = {
            enable = true;
            commands = [
              {
                name = "Ask Gemini AI";
                cmd = "ai-cli -p gemini '%s'";
                prefix = "ai";
                description = "Ask Gemini AI a question";
                terminal = true;
              }
              {
                name = "Ask Gemini (No Terminal)";
                cmd = "ai-cli -p gemini '%s' | wl-copy && notify-send 'AI Response' 'Copied to clipboard'";
                prefix = "gem";
                description = "Ask Gemini and copy response to clipboard";
                terminal = false;
              }
            ];
          };

          # Additional useful modules
          bookmarks.enable = true;
          translation = {
            enable = true;
            provider = "googlefree";
          };

          # Custom commands for frequently used tools
          customCommands = {
            enable = true;
            commands = [
              {
                name = "Rebuild NixOS";
                cmd = "sudo nixos-rebuild switch --flake /home/${config.home.username}/.config/nixos#";
                terminal = true;
              }
              {
                name = "Edit Walker Config";
                cmd = "nvim /home/${config.home.username}/.config/nixos/home/desktop/walker/default.nix";
                terminal = true;
              }
            ];
          };
        };
      };
    };

    # Add auto-start for Hyprland if runAsService is enabled
    wayland.windowManager.hyprland.extraConfig = mkIf (cfg.runAsService && config.wayland.windowManager.hyprland.enable) ''
      exec-once=walker --gapplication-service
    '';

    # Add auto-start for Sway if runAsService is enabled
    wayland.windowManager.sway.config.startup = mkIf (cfg.runAsService && config.wayland.windowManager.sway.enable) [
      { command = "walker --gapplication-service"; }
    ];

    # Add a custom theme file for Gruvbox Material - FLAT DESIGN
    xdg.configFile."walker/themes/gruvbox.css".text = ''
      /* Define Gruvbox Material color scheme variables */
      @define-color bg_h #1d2021;     /* hard dark background */
      @define-color bg #282828;       /* material dark background */
      @define-color bg_s #32302f;     /* soft dark background */
      @define-color bg1 #3c3836;      /* material bg1 */
      @define-color bg2 #504945;      /* material bg2 */
      @define-color bg3 #665c54;      /* material bg3 */
      @define-color bg4 #7c6f64;      /* material bg4 */
      @define-color fg #dcd7ba;       /* material foreground - warmer tone */
      @define-color fg0 #fbf1c7;      /* material fg0 */
      @define-color fg1 #dcd7ba;      /* material fg1 - softer than original */
      @define-color fg2 #c8c093;      /* material fg2 - muted */
      @define-color fg3 #a6a69c;      /* material fg3 - subtle */
      @define-color fg4 #9e9b93;      /* material fg4 */

      /* Gruvbox Material accent colors - more muted and sophisticated */
      @define-color red #e67e80;      /* material red - softer */
      @define-color green #a7c080;    /* material green - sage-like */
      @define-color yellow #dbbc7f;   /* material yellow - golden */
      @define-color blue #7fbbb3;     /* material blue - teal-ish */
      @define-color purple #d699b6;   /* material purple - dusty rose */
      @define-color aqua #83c092;     /* material aqua - mint green */
      @define-color orange #e69875;   /* material orange - coral */

      /* Bright Material accent colors */
      @define-color bright_red #ec5f67;
      @define-color bright_green #99c794;
      @define-color bright_yellow #fac863;
      @define-color bright_blue #6bb6ff;
      @define-color bright_purple #c594c5;
      @define-color bright_aqua #5fb3b3;
      @define-color bright_orange #f99157;

      /* General theme variables */
      @define-color foreground @fg;
      @define-color background @bg;
      @define-color color1 @bright_aqua;

      /* FLAT MATERIAL DESIGN - NO GRADIENTS, NO SHADOWS, NO ROUNDED CORNERS */
      * {
        font-family: "JetBrainsMono Nerd Font";
        font-size: 14px;
        background-clip: border-box;
        border-radius: 0px;
        box-shadow: none;
        background-image: none;
        background: none;
      }

      #window {
        background-color: @bg;
        background: @bg;
        color: @foreground;
        border: 1px solid @bg3;
        border-radius: 0px;
        opacity: 1.0;
        padding: 16px;
        box-shadow: none;
      }

      #box,
      #aiScroll {
        background-color: @bg;
        background: @bg;
        color: @foreground;
        border: none;
        border-radius: 0px;
        opacity: 1.0;
        box-shadow: none;
      }

      /* FLAT SEARCH INPUT - COMPLETELY SEPARATE FROM RESULTS */
      #input {
        background-color: @bg1;
        background: @bg1;
        border: 1px solid @bg3;
        border-radius: 0px;
        color: @foreground;
        margin: 0px 0px 24px 0px;
        padding: 16px;
        opacity: 1.0;
        min-height: 20px;
        box-shadow: none;
        position: relative;
        z-index: 100;
      }

      #input:focus {
        border: 2px solid @bright_aqua;
        background-color: @bg1;
        background: @bg1;
        outline: none;
        box-shadow: none;
      }

      /* FLAT RESULTS LIST - COMPLETELY SEPARATE */
      #list {
        background-color: @bg;
        background: @bg;
        margin: 0px;
        padding: 0px;
        position: relative;
        z-index: 1;
        border-top: 2px solid @bg3;
      }

      /* FLAT LIST ENTRIES */
      #entry {
        background-color: @bg;
        background: @bg;
        padding: 12px 16px;
        margin: 0px;
        border: none;
        border-radius: 0px;
        border-bottom: 1px solid @bg2;
      }

      #entry:selected {
        background-color: @bg2;
        background: @bg2;
        border: none;
        border-left: 4px solid @bright_aqua;
        opacity: 1.0;
      }

      #entry:hover {
        background-color: @bg1;
        background: @bg1;
      }

      #text {
        color: @foreground;
        background: none;
      }

      #text:selected {
        color: @bright_aqua;
        background: none;
      }

      /* FLAT SCROLLBAR */
      #scrollbar {
        background-color: @bg2;
        background: @bg2;
        border-radius: 0px;
        margin: 0px;
        opacity: 1.0;
        width: 8px;
      }

      #scrollbar slider {
        background-color: @bg4;
        background: @bg4;
        border-radius: 0px;
      }

      /* REMOVE ALL GRADIENTS AND EFFECTS */
      .gradient, .shadow, .blur {
        display: none;
      }
    '';
  };
}
