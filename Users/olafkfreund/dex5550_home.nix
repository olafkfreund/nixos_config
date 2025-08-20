{ ... }: {
  imports = [
    # Import common modules
    ../common/default.nix

    # Host-specific imports - headless server configuration (selective imports)
    ../../home/browsers/default.nix # Browser options only (no implementation when disabled)
    ../../home/desktop/terminals/default.nix # Terminal options (provides alacritty, foot, etc. options)
    ../../home/shell/default.nix # CLI shell configuration
    ../../home/development/default.nix # Development tools
    ../../home/media/music.nix # Music configuration (CLI tools)
    ../../home/files.nix # File associations and utilities
    # Desktop option modules (options only, implementations disabled via features)
    ../../home/desktop/sway/default.nix # Provides desktop.sway option
    ../../home/desktop/dunst/default.nix # Provides desktop.dunst option
    ../../home/desktop/swaync/default.nix # Provides desktop.swaync option
    ../../home/desktop/zathura/default.nix # Provides desktop.zathura option
    ../../home/desktop/rofi/default.nix # Provides desktop.rofi option
    ../../home/desktop/obsidian/default.nix # Provides desktop.obsidian option
    ../../home/desktop/swaylock/default.nix # Provides swaylock option
    ../../home/desktop/flameshot/default.nix # Provides desktop.screenshots.flameshot option
    ../../home/desktop/kooha/default.nix # Provides desktop.screenshots.kooha option
    ../../home/desktop/remotedesktop/default.nix # Provides desktop.remotedesktop option
    # ../../home/desktop/walker/default.nix # Not needed on headless server
    # Program modules (provide programs.* options referenced by features system)
    ../../home/desktop/obs/default.nix # Provides programs.obs option
    ../../home/desktop/evince/default.nix # Provides programs.evince option
    ../../home/desktop/kdeconnect/default.nix # Provides programs.kdeconnect option
    ../../home/desktop/slack/default.nix # Provides programs.slack option
    # ../../home/desktop/default.nix   # Excluded - would import all at once
    # ../../home/games/steam.nix       # Excluded - Gaming components
    # ../../hosts/dex5550/nixos/hypr_override.nix  # Removed - Hyprland not needed on server
    # ../../home/desktop/sway/swayosd.nix          # Removed - Sway OSD not needed on server
    ./private.nix
  ];

  # Use the new features system instead of multiple lib.mkForce calls
  features = {
    terminals = {
      enable = false; # Disable GUI terminals for headless server
      alacritty = false;
      foot = false;
      wezterm = false;
      kitty = false;
      ghostty = false;
    };

    editors = {
      enable = true; # Keep CLI editors enabled
      cursor = false; # GUI editor - disabled
      neovim = true; # CLI editor - keep enabled
      vscode = false; # GUI editor - disabled
      zed = false; # GUI editor - disabled
      windsurf = false; # GUI editor - disabled
    };

    browsers = {
      enable = false; # Disable all browsers for headless server
      chrome = false;
      firefox = false;
      edge = false;
      brave = false;
      opera = false;
    };

    desktop = {
      enable = true; # Enable desktop framework but disable all components
      # Note: This avoids feature system evaluation issues while keeping all components disabled
      sway = false;
      dunst = false;
      swaync = false;
      zathura = false; # PDF viewer - not needed on server
      rofi = false; # Application launcher - not needed
      obsidian = false;
      swaylock = false;
      flameshot = false; # Screenshot tool - not needed
      kooha = false; # Screen recorder - not needed
      remotedesktop = false; # Not needed for headless server
      walker = false;

      # Communication and media
      obs = false;
      evince = false; # PDF viewer - not needed on server
      kdeconnect = false;
      slack = false; # GUI communication tool - disabled
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
      zellij = true;
    };

    gaming = {
      enable = false;
      steam = false;
    };

    development = {
      enable = true; # Keep development tools enabled for server management
      languages = true; # Keep language support for development/scripting
      workflow = true; # Keep workflow tools for automation
      productivity = false; # Disable GUI productivity apps
    };
  };

  # Note: media.droidcam is configured in system configuration.nix, not here

  # Add essential packages for headless server (from home/default.nix)
  home.packages = [
    # Nix utilities
    # inputs.self.packages.${pkgs.system}.claude-code  # Not available for headless
  ];

  # Remove Sway configuration - not needed for headless server
  # wayland.windowManager.sway = {
  #   extraConfig = ''
  #     output DP-1 pos 0 0 res 3840x2160
  #   '';
  # };
}
