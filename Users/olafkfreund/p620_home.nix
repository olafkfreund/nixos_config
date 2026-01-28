{ lib
, pkgs
, antigravity-nix
, ...
}: {
  imports = [
    # Import common modules
    ../common/default.nix

    # Host-specific imports
    ../../home/default.nix
    ../../home/games/steam.nix
    ./private.nix
  ];

  # DISABLED: stylix theming - module temporarily disabled due to cachix corruption
  # stylix.targets.firefox.profileNames = [ "default" ];
  # stylix.targets.firefox.enable = false;
  # stylix.targets.gtk.enable = false;
  # stylix.targets.qt.enable = true;

  # Terminal app desktop entries
  programs.k9s.desktopEntry.enable = lib.mkForce true;
  programs.claude-code.desktopEntry.enable = lib.mkForce true;
  programs.neovim.desktopEntry.enable = lib.mkForce true;

  # AI-powered shell command suggestions
  programs.zshAiCmd = {
    enable = true;
    # Uses default: claude-haiku-4-5 (Claude 4.5 - Latest, fast, cost-effective)
    # Or use: claude-sonnet-4-5 (Claude 4.5 - More powerful)
    # Legacy: claude-3-5-haiku-20241022, claude-3-5-sonnet-20241022
    triggerKey = "^G"; # Ctrl+G
    debug = false;
  };

  # GNOME desktop environment (optional - can be enabled/disabled)
  desktop.gnome = {
    enable = true; # Set to true to enable GNOME
    theme = {
      enable = true;
      variant = "dark";
    };
    extensions = {
      enable = true;
      packages = with pkgs.gnomeExtensions; [
        # Add popular extensions for workstation use
        dash-to-dock
        appindicator
        vitals
        blur-my-shell
      ];
    };
    apps = {
      enable = true;
      packages = with pkgs; [
        # Add additional GNOME apps as needed
        gnome-tweaks
        dconf-editor
      ];
    };
    keybindings.enable = true;
  };

  # Use the new features system instead of multiple lib.mkForce calls
  features = {
    terminals = {
      enable = true;
      alacritty = true;
      foot = true;
      wezterm = true;
      kitty = true;
      ghostty = true;
    };

    editors = {
      enable = true;
      cursor = true;
      neovim = true;
      vscode = true;
      windsurf = true;
    };

    browsers = {
      enable = true;
      chrome = true;
      firefox = true;
      edge = false;
      brave = false;
      opera = false;
    };

    desktop = {
      enable = true;
      zathura = true;
      obsidian = true;
      flameshot = false; # Disabled - has issues with Wayland multi-monitor
      waylandScreenshots = true; # Use native Wayland screenshot tools instead
      kooha = true;
      remotedesktop = true;

      # Communication and media
      obs = true;
      evince = true;
      kdeconnect = true;
      slack = true;
    };

    cli = {
      enable = true;
      bat = true;
      direnv = true;
      fzf = true;
      lf = true;
      starship = true;
      yazi = true;
      zoxide = true;
      gh = true;
      markdown = true;
    };

    multiplexers = {
      enable = true;
      tmux = true;
      zellij = false;
    };

    gaming = {
      enable = true;
      steam = true;
    };

    development = {
      enable = true;
      languages = true;
      workflow = true;
      productivity = true;
    };
  };

  # GitLab development configuration for P620
  development.gitlab = {
    enable = true;
    runner.enable = true;
    fluxcd.enable = true;
    ciLocal.enable = true;
  };

  # Override desktop features for P620 (add to existing desktop config)
  features.desktop.quickshell = true;

  # Enable Proton applications suite for P620
  programs.proton = {
    enable = true;
    vpn.enable = true;
    pass.enable = true;
    mail.enable = true;
    authenticator.enable = true;
  };

  # Moltbot AI assistant gateway for Telegram
  # NOTE: Temporarily disabled due to npm binary conflict with nodejs
  # TODO: Re-enable after upstream fix or when telegram userIds configured
  # programs.moltbot = {
  #   enable = true;
  #   telegram.userIds = [ ]; # TODO: Add your Telegram user ID(s)
  #   # Plugins disabled by default - enable individually if needed
  #   # enabledPlugins = { summarize = true; peekaboo = true; };
  # };

  home.packages = [
    # pkgs.customPkgs.rofi-blocks
    # pkgs.msty
    # pkgs.aider-chat-env

    # Google Antigravity - AI coding assistant
    antigravity-nix.packages.${pkgs.stdenv.hostPlatform.system}.default

    # Kosli CLI - Compliance monitoring and DevOps workflows
    pkgs.customPkgs.kosli-cli

    # Aurynk - Android Device Manager
    pkgs.customPkgs.aurynk

    # Newelle - AI Virtual Assistant (GTK4/Libadwaita)
    pkgs.customPkgs.newelle

    # Glim - GitLab CI/CD TUI monitoring
    pkgs.glim

    # Wayfarer - Screen recorder for GNOME/Wayland/pipewire
    pkgs.wayfarer

    # Note: Caprine is already installed via home/desktop/com.nix
  ];

  # Optional: Add additional packages to the Windsurf environment
  editor.windsurf.extraPackages = with pkgs; [
    nixpkgs-fmt
    nil
  ];

  # Optional: Configure Windsurf settings
  editor.windsurf.settings = {
    theme = "gruvbox";
  };

  # P620 Chrome configuration - Modern flags for AMD GPU systems
  programs.chromium = {
    package = lib.mkForce pkgs.google-chrome;
    commandLineArgs = lib.mkForce [
      # Modern Wayland support + Dark Mode (combined features)
      "--enable-features=UseOzonePlatform,WaylandWindowDecorations,WebRTCPipeWireCapturer,WebUIDarkMode"
      "--ozone-platform=wayland"
      "--disable-features=VizDisplayCompositor"

      # Dark mode enforcement
      "--force-dark-mode"

      # Modern AMD GPU acceleration
      "--use-gl=desktop"
      "--enable-gpu-rasterization"
      "--enable-zero-copy"
      "--ignore-gpu-blocklist"
      "--disable-gpu-driver-bug-workarounds"

      # Hardware acceleration for AMD
      "--enable-accelerated-2d-canvas"
      "--enable-accelerated-video-decode"
      "--use-vulkan"

      # Network and stability improvements
      "--enable-quic"
      "--enable-tcp-fast-open"
      "--aggressive-cache-discard"

      # Process and memory optimization
      "--process-per-site"
      "--max_old_space_size=4096"
      "--memory-pressure-off"
    ];
  };

  # Keep Firefox as backup
  programs.firefox = {
    enable = true;
    profiles.default = {
      settings = {
        "widget.use-xdg-desktop-portal.file-picker" = 1;
        "media.ffmpeg.vaapi.enabled" = true;
      };
    };
  };
}
