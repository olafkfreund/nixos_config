{
  inputs,
  lib,
  pkgs,
  ...
}: {
  imports = [
    # Import common modules
    ../common/default.nix

    # Host-specific imports - headless server configuration  
    ../../home/shell/default.nix     # Only shell components for headless server
    ../../home/development/default.nix # Development tools for server management
    # ../../home/default.nix          # Removed - includes GUI desktop modules
    # ../../hosts/dex5550/nixos/hypr_override.nix  # Removed - Hyprland not needed on server
    # ../../home/desktop/sway/default.nix          # Removed - Sway not needed on server
    # ../../home/desktop/sway/swayosd.nix          # Removed - Sway OSD not needed on server
    ./private.nix
  ];

  # Use the new features system instead of multiple lib.mkForce calls
  features = {
    terminals = {
      enable = false;  # Disable GUI terminals for headless server
      alacritty = false;
      foot = false;
      wezterm = false;
      kitty = false;
      ghostty = false;
    };

    editors = {
      enable = true;   # Keep CLI editors enabled
      cursor = false;  # GUI editor - disabled
      neovim = true;   # CLI editor - keep enabled
      vscode = false;  # GUI editor - disabled  
      zed = false;     # GUI editor - disabled
      windsurf = false; # GUI editor - disabled
    };

    browsers = {
      enable = false;  # Disable all browsers for headless server
      chrome = false;
      firefox = false;
      edge = false;
      brave = false;
      opera = false;
    };

    desktop = {
      enable = false;  # Disable all desktop applications for headless server
      sway = false;
      dunst = false;
      swaync = false;
      zathura = false;  # PDF viewer - not needed on server
      rofi = false;     # Application launcher - not needed
      obsidian = false;
      swaylock = false;
      flameshot = false; # Screenshot tool - not needed
      kooha = false;     # Screen recorder - not needed
      remotedesktop = false; # Not needed for headless server
      walker = false;

      # Communication and media
      obs = false;
      evince = false;    # PDF viewer - not needed on server
      kdeconnect = false;
      slack = false;     # GUI communication tool - disabled
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
      enable = true;   # Keep development tools enabled for server management
      languages = true; # Keep language support for development/scripting
      workflow = true;  # Keep workflow tools for automation
      productivity = false; # Disable GUI productivity apps
    };
  };

  # Note: media.droidcam is configured in system configuration.nix, not here

  # Remove Sway configuration - not needed for headless server
  # wayland.windowManager.sway = {
  #   extraConfig = ''
  #     output DP-1 pos 0 0 res 3840x2160
  #   '';
  # };
}
