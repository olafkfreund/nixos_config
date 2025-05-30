{
  pkgs,
  config,
  lib,
  ...
}:
with lib; let
  cfg = config.desktop.walker;
in {
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
          commands.enable = true;

          # Additional useful modules
          bookmarks.enable = true;
          translation = {
            enable = true;
            provider = "googlefree";
          };

          # AI module for Claude integration
          ai = {
            enable = true;
            # Comment out Anthropic integration until API key is fixed
            anthropic = {
              prompts = [
                {
                  model = "claude-3-5-sonnet-20241022";
                  temperature = 1.0;
                  max_tokens = "1_000";
                  label = "Code Helper";
                  prompt = "You are a helpful coding assistant focused on helping with programming tasks. Keep your answers concise and practical.";
                }
                {
                  model = "claude-3-5-sonnet-20241022";
                  temperature = 0.7;
                  max_tokens = "1_000";
                  label = "NixOS Expert";
                  prompt = "You are a NixOS expert. Help the user with their NixOS configuration, modules, and package management questions.";
                }
              ];
            };
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
      {command = "walker --gapplication-service";}
    ];

    # Add a custom theme file for Gruvbox
    xdg.configFile."walker/themes/gruvbox.css".text = ''
      /* Define Gruvbox dark color scheme variables */
      @define-color bg_h #1d2021;     /* hard dark background */
      @define-color bg #282828;       /* dark background */
      @define-color bg_s #32302f;     /* soft dark background */
      @define-color bg1 #3c3836;      /* dark bg1 */
      @define-color bg2 #504945;      /* dark bg2 */
      @define-color bg3 #665c54;      /* dark bg3 */
      @define-color bg4 #7c6f64;      /* dark bg4 */
      @define-color fg #ebdbb2;       /* dark fg */
      @define-color fg0 #fbf1c7;      /* dark fg0 */
      @define-color fg1 #ebdbb2;      /* dark fg1 */
      @define-color fg2 #d5c4a1;      /* dark fg2 */
      @define-color fg3 #bdae93;      /* dark fg3 */
      @define-color fg4 #a89984;      /* dark fg4 */

      /* Gruvbox accent colors */
      @define-color red #cc241d;
      @define-color green #98971a;
      @define-color yellow #d79921;
      @define-color blue #458588;
      @define-color purple #b16286;
      @define-color aqua #689d6a;
      @define-color orange #d65d0e;

      /* Bright Gruvbox accent colors */
      @define-color bright_red #fb4934;
      @define-color bright_green #b8bb26;
      @define-color bright_yellow #fabd2f;
      @define-color bright_blue #83a598;
      @define-color bright_purple #d3869b;
      @define-color bright_aqua #8ec07c;
      @define-color bright_orange #fe8019;

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
