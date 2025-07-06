# Enhanced Applications Configuration with Feature Flags
{
  config,
  lib,
  pkgs,
  host ? "default",
  ...
}:
with lib;
let
  # Import host-specific variables if available
  hostVars = 
    if builtins.pathExists ../../../hosts/${host}/variables.nix
    then import ../../../hosts/${host}/variables.nix
    else {};
  
  # Application feature flags
  cfg = {
    # Core applications
    core = {
      enable = true;
    };
    
    # Editors
    editors = {
      neovim = true;
      cursor = true;
      vscode = true;
      zed = true;
      windsurf = true;
    };
    
    # Browsers
    browsers = {
      chrome = true;
      firefox = true;
      edge = false;
      brave = false;
      opera = false;
    };
    
    # Communication
    communication = {
      slack = true;
      element = true;
      fractal = true;
      teams = true;
      vesktop = true;
      kdeconnect = true;
    };
    
    # Media and Content
    media = {
      obs = true;
      flameshot = true;
      kooha = true;
      evince = true;
      zathura = true;
      obsidian = true;
      libreoffice = true;
    };
    
    # Development Tools
    development = {
      dbeaver = true;
      github = true;
      databases = true;
    };
    
    # CLI Tools
    cli = {
      bat = true;
      starship = true;
      yazi = true;
      fzf = true;
      direnv = true;
      zoxide = true;
      lf = true;
      markdown = true;
    };
    
    # Terminal Multiplexers
    multiplexers = {
      tmux = true;
      zellij = true;
    };
    
    # Gaming
    gaming = {
      steam = true;
      moonlight = true;
      lookingGlass = true;
    };
    
    # System Tools
    system = {
      walker = true;
      polychromatic = true; # For Razer devices
      lanmouse = true;
    };
  };

in {
  # Enhanced applications configuration
  home.packages = with pkgs; mkIf cfg.core.enable (
    # Base system packages
    [
      # Essential tools
      imagemagick
      ffmpegthumbnailer
      unar
      poppler
      fontpreview
    ] ++
    
    # Editors
    optionals cfg.editors.neovim [
      neovim
    ] ++
    optionals cfg.editors.cursor [
      cursor
    ] ++
    optionals cfg.editors.vscode [
      vscode
    ] ++
    optionals cfg.editors.zed [
      zed-editor
    ] ++
    optionals cfg.editors.windsurf [
      windsurf
    ] ++
    
    # Browsers
    optionals cfg.browsers.chrome [
      google-chrome
    ] ++
    optionals cfg.browsers.firefox [
      firefox
    ] ++
    optionals cfg.browsers.edge [
      microsoft-edge
    ] ++
    optionals cfg.browsers.brave [
      brave
    ] ++
    optionals cfg.browsers.opera [
      opera
    ] ++
    
    # Communication
    optionals cfg.communication.slack [
      slack
    ] ++
    optionals cfg.communication.element [
      element-desktop
    ] ++
    optionals cfg.communication.fractal [
      fractal
    ] ++
    optionals cfg.communication.teams [
      teams-for-linux
    ] ++
    optionals cfg.communication.vesktop [
      vesktop
    ] ++
    optionals cfg.communication.kdeconnect [
      kdePackages.kdeconnect-kde
    ] ++
    
    # Media and Content
    optionals cfg.media.obs [
      obs-studio
    ] ++
    optionals cfg.media.flameshot [
      flameshot
    ] ++
    optionals cfg.media.kooha [
      kooha
    ] ++
    optionals cfg.media.evince [
      evince
    ] ++
    optionals cfg.media.zathura [
      zathura
      zathura-pdf-mupdf
      zathura-djvu
      zathura-ps
      zathura-cb
    ] ++
    optionals cfg.media.obsidian [
      obsidian
    ] ++
    optionals cfg.media.libreoffice [
      libreoffice
    ] ++
    
    # Development Tools
    optionals cfg.development.dbeaver [
      dbeaver-bin
    ] ++
    optionals cfg.development.github [
      gh
      lazygit
    ] ++
    
    # CLI Tools
    optionals cfg.cli.bat [
      bat
      # Bat extras
      (writeShellScriptBin "batman" ''exec ${bat}/bin/bat --plain --language=man "$@"'')
      (writeShellScriptBin "batgrep" ''exec ${ripgrep}/bin/rg --json -C 3 "$@" | ${bat}/bin/bat --language=json'')
      (writeShellScriptBin "batpipe" ''exec ${bat}/bin/bat --paging=never "$@"'')
    ] ++
    optionals cfg.cli.starship [
      starship
    ] ++
    optionals cfg.cli.yazi [
      yazi
    ] ++
    optionals cfg.cli.fzf [
      fzf
    ] ++
    optionals cfg.cli.direnv [
      direnv
    ] ++
    optionals cfg.cli.zoxide [
      zoxide
    ] ++
    optionals cfg.cli.lf [
      lf
    ] ++
    optionals cfg.cli.markdown [
      mdr
      slippy
      md-tui
    ] ++
    
    # Terminal Multiplexers
    optionals cfg.multiplexers.tmux [
      tmux
      tmate
    ] ++
    optionals cfg.multiplexers.zellij [
      zellij
      zjstatus
    ] ++
    
    # Gaming
    optionals cfg.gaming.steam [
      moonlight-qt
    ] ++
    optionals cfg.gaming.lookingGlass [
      looking-glass-client
    ] ++
    
    # System Tools
    optionals cfg.system.walker [
      walker
    ] ++
    optionals cfg.system.polychromatic [
      polychromatic
    ] ++
    optionals cfg.system.lanmouse [
      lan-mouse
    ]
  );

  # Program configurations
  programs = mkMerge [
    # Chromium/Chrome configuration
    (mkIf cfg.browsers.chrome {
      chromium = {
        enable = true;
        package = pkgs.google-chrome;
        commandLineArgs = [
          "--enable-features=UseOzonePlatform,VaapiVideoDecoder,VaapiVideoEncoder"
          "--ozone-platform=wayland"
          "--enable-gpu-rasterization"
          "--enable-zero-copy"
        ];
      };
    })
    
    # Firefox configuration
    (mkIf cfg.browsers.firefox {
      firefox = {
        enable = true;
        package = pkgs.firefox;
        profiles.default = {
          isDefault = true;
          settings = {
            "browser.fullscreen.autohide" = false;
            "browser.tabs.inTitlebar" = 0;
            "toolkit.legacyUserProfileCustomizations.stylesheets" = true;
            "browser.uidensity" = 1;
            "media.ffmpeg.vaapi.enabled" = true;
            "gfx.webrender.all" = true;
          };
        };
      };
    })
    
    # OBS Studio configuration
    (mkIf cfg.media.obs {
      obs-studio = {
        enable = true;
        plugins = with pkgs.obs-studio-plugins; [
          wlrobs
        ];
      };
    })
  ];

  # Service configurations
  services = mkMerge [
    # KDE Connect
    (mkIf cfg.communication.kdeconnect {
      kdeconnect = {
        enable = true;
        indicator = true;
      };
    })
  ];

  # XDG Desktop entries for Wayland optimization
  xdg.desktopEntries = mkMerge [
    (mkIf cfg.media.obsidian {
      obsidian-wayland = {
        name = "Obsidian (Wayland)";
        comment = "Knowledge management application";
        exec = "${pkgs.obsidian}/bin/obsidian --enable-features=UseOzonePlatform --ozone-platform=wayland";
        icon = "obsidian";
        categories = [ "Office" "TextEditor" ];
      };
    })
  ];

  # Environment variables
  home.sessionVariables = mkMerge [
    (mkIf cfg.cli.direnv {
      DIRENV_CONFIG = "${config.xdg.configHome}/direnv";
    })
    (mkIf cfg.editors.cursor {
      CURSOR_USER_CONFIG_DIR = "${config.xdg.configHome}/cursor";
    })
  ];

  # File configurations
  home.file = mkMerge [
    # Starship configuration
    (mkIf cfg.cli.starship {
      ".config/starship.toml".text = ''
        format = """
        [󱄅](bold blue) $all$character
        """
        
        [character]
        success_symbol = "[❯](bold green)"
        error_symbol = "[❯](bold red)"
        
        [directory]
        style = "bold cyan"
        truncation_length = 3
        truncate_to_repo = false
        
        [git_branch]
        symbol = " "
        style = "bold purple"
        
        [git_status]
        style = "bold yellow"
      '';
    })
  ];
}