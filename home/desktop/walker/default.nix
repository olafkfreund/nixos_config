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
          centered = true; # Add this to center Walker on the screen
          icon_theme = "Adwaita"; # Explicit icon theme to avoid mismatches
          icon_size = 26; # Match the system theme size of 26px
        };
        as_window = false;
        list = {
          height = 800;
          width = 1000;
          center = true; # Add this to explicitly center the list
        };
        hotreload_theme = true;
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

    # Add a custom theme file for Gruvbox Material
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
      @define-color background alpha(@bg, 0.95);
      @define-color color1 @bright_aqua;
      @define-color shadow rgba(0, 0, 0, 0.3);

      /* Global styles */
      * {
        font-family: "JetBrainsMono Nerd Font";
        font-size: 14px;
        background-clip: border-box;
      }

      #window,
      #box,
      #aiScroll {
        background-color: @background;
        color: @foreground;
        border: 1px solid @bg3;
        border-radius: 8px;
      }

      #input {
        background-color: alpha(@bg1, 0.7);
        border: 1px solid @bg3;
        border-radius: 6px;
        color: @foreground;
        margin: 8px;
        padding: 8px;
      }

      #input:focus {
        border-color: @bright_aqua;
      }

      #list {
        background: transparent;
        margin: 8px;
      }

      #entry {
        padding: 8px;
        margin: 2px 8px;
        border-radius: 6px;
      }

      #entry:selected {
        background-color: alpha(@bg2, 0.7);
        border: 1px solid @bright_aqua;
      }

      #text {
        color: @foreground;
      }

      #text:selected {
        color: @bright_aqua;
      }

      #scrollbar {
        background-color: alpha(@bg1, 0.7);
        border-radius: 6px;
        margin: 5px;
      }

      #scrollbar slider {
        background-color: @bg4;
        border-radius: 6px;
      }
    '';
  };
}
