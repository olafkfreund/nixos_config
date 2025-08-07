# Desktop Module Template
#
# This template is for desktop environment components, window managers,
# display managers, and desktop applications.
#
# Usage:
# 1. Copy to modules/desktop/COMPONENT_NAME.nix
# 2. Replace PLACEHOLDER values
# 3. Add to modules/desktop/default.nix imports
# 4. Enable with: features.desktop.COMPONENT_NAME = true;

{ config
, lib
, pkgs
, ...
}:
with lib; let
  cfg = config.modules.desktop.COMPONENT_NAME;
in
{
  options.modules.desktop.COMPONENT_NAME = {
    enable = mkEnableOption "COMPONENT_NAME desktop component";

    # Package selection
    package = mkOption {
      type = types.package;
      default = pkgs.COMPONENT_PACKAGE;
      description = "The COMPONENT_NAME package to use";
    };

    # Display configuration
    display = {
      resolution = mkOption {
        type = types.str;
        default = "1920x1080";
        description = "Default display resolution";
        example = "2560x1440";
      };

      refreshRate = mkOption {
        type = types.int;
        default = 60;
        description = "Display refresh rate in Hz";
        example = 144;
      };

      scaling = mkOption {
        type = types.float;
        default = 1.0;
        description = "Display scaling factor";
        example = 1.5;
      };
    };

    # Input configuration
    input = {
      keyboard = {
        layout = mkOption {
          type = types.str;
          default = "us";
          description = "Keyboard layout";
          example = "gb";
        };

        variant = mkOption {
          type = types.str;
          default = "";
          description = "Keyboard variant";
          example = "dvorak";
        };

        options = mkOption {
          type = types.listOf types.str;
          default = [ ];
          description = "Keyboard options";
          example = [ "caps:escape" "compose:ralt" ];
        };
      };

      mouse = {
        sensitivity = mkOption {
          type = types.float;
          default = 1.0;
          description = "Mouse sensitivity";
          example = 1.5;
        };

        acceleration = mkOption {
          type = types.bool;
          default = true;
          description = "Enable mouse acceleration";
        };
      };

      touchpad = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "Enable touchpad";
        };

        naturalScrolling = mkOption {
          type = types.bool;
          default = false;
          description = "Enable natural scrolling";
        };

        tapToClick = mkOption {
          type = types.bool;
          default = true;
          description = "Enable tap to click";
        };
      };
    };

    # Theme and appearance
    theme = {
      name = mkOption {
        type = types.str;
        default = "default";
        description = "Theme name";
        example = "Adwaita-dark";
      };

      iconTheme = mkOption {
        type = types.str;
        default = "default";
        description = "Icon theme name";
        example = "Papirus";
      };

      cursorTheme = mkOption {
        type = types.str;
        default = "default";
        description = "Cursor theme name";
        example = "Bibata-Modern-Ice";
      };

      font = {
        name = mkOption {
          type = types.str;
          default = "sans-serif";
          description = "Default font name";
          example = "Noto Sans";
        };

        size = mkOption {
          type = types.int;
          default = 11;
          description = "Default font size";
          example = 12;
        };
      };
    };

    # Application defaults
    defaultApplications = mkOption {
      type = types.attrsOf types.str;
      default = { };
      description = "Default applications for file types";
      example = literalExpression ''
        {
          "text/plain" = "nvim.desktop";
          "image/jpeg" = "feh.desktop";
          "application/pdf" = "zathura.desktop";
        }
      '';
    };

    # Autostart applications
    autostart = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Applications to start automatically";
      example = [ "firefox" "thunderbird" ];
    };

    # Keybindings
    keybindings = mkOption {
      type = types.attrsOf types.str;
      default = { };
      description = "Custom keybindings";
      example = literalExpression ''
        {
          "Super+Return" = "kitty";
          "Super+d" = "rofi -show drun";
          "Super+Shift+q" = "kill";
        }
      '';
    };

    # Workspace configuration
    workspaces = {
      count = mkOption {
        type = types.int;
        default = 4;
        description = "Number of workspaces";
      };

      names = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "Workspace names";
        example = [ "web" "dev" "chat" "media" ];
      };
    };

    # Panel/Bar configuration
    panel = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable desktop panel/bar";
      };

      position = mkOption {
        type = types.enum [ "top" "bottom" "left" "right" ];
        default = "top";
        description = "Panel position";
      };

      height = mkOption {
        type = types.int;
        default = 32;
        description = "Panel height in pixels";
      };

      modules = mkOption {
        type = types.listOf types.str;
        default = [ "workspaces" "window-title" "clock" "system-tray" ];
        description = "Panel modules to enable";
      };
    };

    # Additional features
    enableCompositor = mkOption {
      type = types.bool;
      default = true;
      description = "Enable compositor for effects";
    };

    enableNotifications = mkOption {
      type = types.bool;
      default = true;
      description = "Enable desktop notifications";
    };

    enableScreenshots = mkOption {
      type = types.bool;
      default = true;
      description = "Enable screenshot tools";
    };

    enableWallpaper = mkOption {
      type = types.bool;
      default = true;
      description = "Enable wallpaper management";
    };

    wallpaper = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Default wallpaper path";
      example = literalExpression "./wallpapers/default.jpg";
    };
  };

  config = mkIf cfg.enable {
    # Core desktop packages
    environment.systemPackages = with pkgs; [
      cfg.package
    ]
    # Screenshot tools
    ++ optionals cfg.enableScreenshots [
      grim
      slurp
      swappy
    ]
    # Notification daemon
    ++ optionals cfg.enableNotifications [
      libnotify
      dunst
    ]
    # Wallpaper tools
    ++ optionals cfg.enableWallpaper [
      feh
      swaybg
    ];

    # Desktop environment configuration
    services.xserver = {
      enable = true;

      # Display manager
      displayManager = {
        # Configure based on component type
        # lightdm.enable = true;
        # gdm.enable = true;
      };

      # Window manager / Desktop environment
      # windowManager.COMPONENT_NAME.enable = true;
      # desktopManager.COMPONENT_NAME.enable = true;
    };

    # Wayland configuration (if applicable)
    # programs.wayland.enable = true;
    # programs.COMPONENT_NAME = {
    #   enable = true;
    #   package = cfg.package;
    # };

    # XDG Portal configuration
    xdg.portal = {
      enable = true;
      extraPortals = with pkgs; [
        # xdg-desktop-portal-COMPONENT_NAME
      ];
      config = {
        common = {
          default = [ "COMPONENT_NAME" "gtk" ];
        };
      };
    };

    # Input configuration
    services.xserver.xkb = {
      layout = cfg.input.keyboard.layout;
      variant = cfg.input.keyboard.variant;
      options = concatStringsSep "," cfg.input.keyboard.options;
    };

    # Touchpad configuration
    services.libinput = mkIf cfg.input.touchpad.enable {
      enable = true;
      touchpad = {
        naturalScrolling = cfg.input.touchpad.naturalScrolling;
        tapping = cfg.input.touchpad.tapToClick;
      };
    };

    # Font configuration
    fonts = {
      packages = with pkgs; [
        # Add desktop fonts
        noto-fonts
        noto-fonts-cjk
        noto-fonts-emoji
        liberation_ttf
        fira-code
        fira-code-symbols
      ];

      fontconfig = {
        defaultFonts = {
          serif = [ cfg.theme.font.name ];
          sansSerif = [ cfg.theme.font.name ];
          monospace = [ "Fira Code" cfg.theme.font.name ];
        };
      };
    };

    # Default applications
    xdg.mime.defaultApplications = cfg.defaultApplications;

    # Autostart applications
    systemd.user.services = listToAttrs (map
      (app: {
        name = "autostart-${app}";
        value = {
          description = "Autostart ${app}";
          after = [ "graphical-session.target" ];
          partOf = [ "graphical-session.target" ];
          serviceConfig = {
            Type = "simple";
            ExecStart = "${app}";
            Restart = "on-failure";
          };
        };
      })
      cfg.autostart);

    # Desktop-specific environment variables
    environment.sessionVariables = {
      # XDG_CURRENT_DESKTOP = "COMPONENT_NAME";
      # COMPONENT_NAME_CONFIG_HOME = "$HOME/.config/COMPONENT_NAME";
    };

    # Compositor configuration
    # services.picom = mkIf cfg.enableCompositor {
    #   enable = true;
    #   # compositor settings
    # };

    # Notification daemon
    services.dunst = mkIf cfg.enableNotifications {
      enable = true;
      settings = {
        global = {
          geometry = "300x5-30+20";
          transparency = 10;
          font = "${cfg.theme.font.name} ${toString cfg.theme.font.size}";
        };
      };
    };

    # GTK theme configuration
    programs.dconf.enable = true;

    # Hardware acceleration
    hardware.graphics.enable = true;

    # Sound system
    security.rtkit.enable = true;
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
    };

    # Validation assertions
    assertions = [
      {
        assertion = cfg.workspaces.count > 0;
        message = "COMPONENT_NAME: workspace count must be greater than 0";
      }
      {
        assertion = cfg.workspaces.names == [ ] || length cfg.workspaces.names == cfg.workspaces.count;
        message = "COMPONENT_NAME: workspace names length must match workspace count";
      }
      {
        assertion = cfg.display.refreshRate > 0;
        message = "COMPONENT_NAME: refresh rate must be greater than 0";
      }
    ];

    # Desktop-specific warnings
    warnings = [
      (mkIf (cfg.enableCompositor && !config.hardware.graphics.enable) ''
        COMPONENT_NAME: Compositor is enabled but hardware acceleration is not.
        Consider enabling hardware.graphics for better performance.
      '')
      (mkIf (cfg.wallpaper != null && !cfg.enableWallpaper) ''
        COMPONENT_NAME: Wallpaper path specified but wallpaper management is disabled.
        Set enableWallpaper = true to use the specified wallpaper.
      '')
      (mkIf (cfg.autostart != [ ] && !cfg.panel.enable) ''
        COMPONENT_NAME: Autostart applications configured but panel is disabled.
        Users may not have easy access to running applications.
      '')
    ];
  };
}
