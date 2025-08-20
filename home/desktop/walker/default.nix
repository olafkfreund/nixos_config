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
    # Install Walker as a package since programs.walker doesn't exist in home-manager
    home.packages = [ pkgs.walker ];

    # Create Walker configuration manually via xdg.configFile
    xdg.configFile."walker/config.toml".text = ''
      [search]
      placeholder = "Search..."

      [ui]
      fullscreen = false
      width = 1000
      height = 800
      icon_theme = "Adwaita"
      icon_size = 26
      show_search = true

      [ui.anchors]
      left = false
      right = false
      top = false
      bottom = false

      [ui.margins]
      top = 20
      bottom = 20
      left = 20
      right = 20

      [list]
      height = 650
      width = 960
      margin = 20

      hotreload_theme = false
      theme = "gruvbox"
    '';

    # Add auto-start for Hyprland if runAsService is enabled
    wayland.windowManager.hyprland.extraConfig = mkIf (cfg.runAsService && config.wayland.windowManager.hyprland.enable) ''
      exec-once=walker --gapplication-service
    '';

    # Add auto-start for Sway if runAsService is enabled
    wayland.windowManager.sway.config.startup = mkIf (cfg.runAsService && config.wayland.windowManager.sway.enable) [
      { command = "walker --gapplication-service"; }
    ];

    # Add a custom theme file that uses Stylix colors dynamically
    xdg.configFile."walker/themes/gruvbox.css".text = ''
      /* Stylix integration - Use system theme colors dynamically */
      @define-color bg_h #${config.lib.stylix.colors.base00};     /* darkest background */
      @define-color bg #${config.lib.stylix.colors.base00};       /* main background */
      @define-color bg_s #${config.lib.stylix.colors.base01};     /* soft background */
      @define-color bg1 #${config.lib.stylix.colors.base01};      /* lighter bg */
      @define-color bg2 #${config.lib.stylix.colors.base02};      /* selection bg */
      @define-color bg3 #${config.lib.stylix.colors.base03};      /* comments, invisibles */
      @define-color bg4 #${config.lib.stylix.colors.base04};      /* dark foreground */
      @define-color fg #${config.lib.stylix.colors.base05};       /* main foreground */
      @define-color fg0 #${config.lib.stylix.colors.base07};      /* lightest foreground */
      @define-color fg1 #${config.lib.stylix.colors.base05};      /* default fg */
      @define-color fg2 #${config.lib.stylix.colors.base06};      /* light fg */
      @define-color fg3 #${config.lib.stylix.colors.base04};      /* dark fg */
      @define-color fg4 #${config.lib.stylix.colors.base03};      /* darkest fg */

      /* Stylix accent colors from base16 scheme */
      @define-color red #${config.lib.stylix.colors.base08};      /* red */
      @define-color orange #${config.lib.stylix.colors.base09};   /* orange */
      @define-color yellow #${config.lib.stylix.colors.base0A};   /* yellow */
      @define-color green #${config.lib.stylix.colors.base0B};    /* green */
      @define-color aqua #${config.lib.stylix.colors.base0C};     /* cyan/aqua */
      @define-color blue #${config.lib.stylix.colors.base0D};     /* blue */
      @define-color purple #${config.lib.stylix.colors.base0E};   /* purple/magenta */
      @define-color brown #${config.lib.stylix.colors.base0F};    /* brown */

      /* Bright variants (using the same colors for consistency) */
      @define-color bright_red #${config.lib.stylix.colors.base08};
      @define-color bright_green #${config.lib.stylix.colors.base0B};
      @define-color bright_yellow #${config.lib.stylix.colors.base0A};
      @define-color bright_blue #${config.lib.stylix.colors.base0D};
      @define-color bright_purple #${config.lib.stylix.colors.base0E};
      @define-color bright_aqua #${config.lib.stylix.colors.base0C};
      @define-color bright_orange #${config.lib.stylix.colors.base09};

      /* General theme variables */
      @define-color foreground @fg;
      @define-color background @bg;
      @define-color color1 @bright_aqua;

      /* Font configuration from Stylix */
      * {
        font-family: "${config.stylix.fonts.monospace.name}";
        font-size: ${toString config.stylix.fonts.sizes.applications}px;
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
        opacity: ${toString config.stylix.opacity.desktop};
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

      /* Search input - separate from results */
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

      /* Results list */
      #list {
        background-color: @bg;
        background: @bg;
        margin: 0px;
        padding: 0px;
        position: relative;
        z-index: 1;
        border-top: 2px solid @bg3;
      }

      /* List entries */
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

      /* Scrollbar */
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

      /* Remove all gradients and effects for flat design */
      .gradient, .shadow, .blur {
        display: none;
      }
    '';
  };
}
