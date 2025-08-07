# Enhanced Modern Zellij Configuration
# Optimized for speed, maintainability, and seamless integration with Zsh/Starship
{
  pkgs,
  config,
  lib,
  ...
}: 
with lib; let 
  cfg = config.multiplexer.zellij;
in {
  options.multiplexer.zellij = {
    enable = mkEnableOption {
      default = false;
      description = "Enable zellij";
    };
  };
  config = mkIf cfg.enable {
    programs.zellij = {
      enable = true;
      enableBashIntegration = false;
      enableZshIntegration = false;  # Disable auto-start
      package = pkgs.zellij;
      
      # Enhanced settings for modern development workflow
      settings = {
        # Core configuration
        default-shell = "zsh";
        simplified_ui = true;
        copy_command = lib.getExe' pkgs.wl-clipboard "wl-copy";
        copy_on_select = false;
        hide_session_name = false;  # Show session name for better context
        session_serialization = true;
        
        # Modern UI enhancements
        pane_frames = true;  # Enable for better visual separation
        default_layout = "compact";
        theme = lib.mkForce "gruvbox-dark";
        
        # Enhanced UI configuration
        ui = {
          pane_frames = {
            hide_session_name = false;
            rounded_corners = true;
          };
        };
        
        # Essential plugins for productivity (only basic ones that work)
        plugins = [
          "status-bar"
          "tab-bar" 
          "compact-bar"
        ];
        
        # Performance and behavior optimizations
        scrollback_editor = "${pkgs.neovim}/bin/nvim";
        default_mode = "normal";
        mouse_mode = true;
        
        # Basic keybindings - simplified to avoid parsing errors
        keybinds = {
          normal = {
            # Basic pane management
            "bind \"h\"" = { MoveFocus = "Left"; };
            "bind \"j\"" = { MoveFocus = "Down"; };
            "bind \"k\"" = { MoveFocus = "Up"; };
            "bind \"l\"" = { MoveFocus = "Right"; };
            
            # Basic tab management
            "bind \"t\"" = { NewTab = {}; };
            "bind \"x\"" = { CloseTab = {}; };
            
            # Basic pane splitting
            "bind \"|\"" = { NewPane = "Right"; };
            "bind \"-\"" = { NewPane = "Down"; };
            
            # Basic functionality
            "bind \"f\"" = { ToggleFloatingPanes = {}; };
            "bind \"z\"" = { ToggleFocusFullscreen = {}; };
          };
          
          # Simplified scroll mode
          scroll = {
            "bind \"j\"" = { ScrollDown = {}; };
            "bind \"k\"" = { ScrollUp = {}; };
            "bind \"d\"" = { HalfPageScrollDown = {}; };
            "bind \"u\"" = { HalfPageScrollUp = {}; };
          };
        };
        
        # Enhanced theming
        themes = {
          gruvbox-dark = {
            bg = "#282828";
            fg = "#ebdbb2";
            red = "#cc241d";
            green = "#98971a";
            yellow = "#d79921";
            blue = "#458588";
            magenta = "#b16286";
            orange = "#d65d0e";
            cyan = "#689d6a";
            black = "#1d2021";
            white = "#ebdbb2";
          };
        };
      };
    };
    
    # Enhanced shell aliases for productivity
    home.shellAliases = {
      zj = "zellij";
      zja = "zellij attach";
      zjd = "zellij delete-session";
      zjl = "zellij list-sessions";
      zjk = "zellij kill-session";
      zjr = "zellij run";
      zje = "zellij edit";
    };
    
    # Additional packages for enhanced Zellij experience
    home.packages = with pkgs; [
      zjstatus      # Enhanced status bar
      tmate         # Terminal sharing
    ];
    
    # Zellij configuration directory setup
    xdg.configFile."zellij/layouts/development.kdl".text = ''
      layout {
          pane size=1 borderless=true {
              plugin location="zellij:tab-bar"
          }
          pane split_direction="vertical" {
              pane split_direction="horizontal" {
                  pane size="70%" {
                      name "editor"
                  }
                  pane size="30%" {
                      name "terminal"
                  }
              }
              pane size="25%" {
                  name "logs"
              }
          }
          pane size=2 borderless=true {
              plugin location="zellij:status-bar"
          }
      }
    '';
    
    xdg.configFile."zellij/layouts/simple.kdl".text = ''
      layout {
          pane size=1 borderless=true {
              plugin location="zellij:tab-bar"
          }
          pane
          pane size=2 borderless=true {
              plugin location="zellij:status-bar"
          }
      }
    '';
  };
}