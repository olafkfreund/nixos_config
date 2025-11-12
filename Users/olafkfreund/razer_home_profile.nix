# Razer Home Configuration - Mobile Developer Profile
# Uses mobile-developer composition (developer + laptop-user)
{ lib, pkgs, config, ... }: {
  imports = [
    # Import common user configuration
    ../common/default.nix
    ./private.nix

    # Import both developer and laptop-user profiles
    ../../home/profiles/developer/default.nix
    ../../home/profiles/laptop-user/default.nix

    # Host-specific configurations for laptop
    ../../home/desktop/sway/default.nix
    ../../home/desktop/sway/swayosd.nix
  ];

  # Profile metadata
  meta.profile = {
    name = "mobile-developer";
    type = "composition";
    description = "Mobile development setup with power optimization";
    combines = [ "developer" "laptop-user" ];
    host = "razer";
  };

  # Razer-specific feature overrides for mobile optimization
  features = {
    # Limited gaming on laptop for battery life
    gaming = {
      enable = true;
      steam = true; # Can be useful for indie games
    };

    # Development optimized for mobile
    development = {
      enable = true;
      languages = true; # Essential languages only
      workflow = true;
      productivity = false; # Skip heavy productivity tools
    };

    # Mobile-optimized terminals
    terminals = {
      enable = true;
      alacritty = true; # Lightweight and efficient
      foot = true; # Wayland-native
      wezterm = false; # Skip resource-intensive terminals
      kitty = true;
      ghostty = false;
    };

    # Battery-optimized editors
    editors = {
      enable = true;
      cursor = false; # Skip AI-powered editor for battery
      neovim = true;
      vscode = true; # Primary for development
      zed = true; # Lightweight alternative
      windsurf = false; # Skip web-based editor
    };
  };

  # Razer laptop specific packages
  home.packages = with pkgs; [
    # Laptop-specific utilities
    brightnessctl
    playerctl
    pamixer
    powertop
    acpi

    # Intel/NVIDIA specific tools for Razer
    intel-gpu-tools
    nvidia-system-monitor-qt

    # Mobile development tools
    android-tools

    # Battery optimization
    tlp
  ];

  # Laptop-optimized browser configuration
  programs.chromium = {
    package = lib.mkForce pkgs.google-chrome;
    commandLineArgs = lib.mkForce [
      # Wayland support for better laptop integration
      "--enable-features=UseOzonePlatform,WaylandWindowDecorations"
      "--ozone-platform=wayland"

      # NVIDIA Optimus optimizations for Razer
      "--use-gl=desktop"
      "--enable-gpu-rasterization"
      "--ignore-gpu-blocklist"

      # Battery optimization
      "--enable-aggressive-domstorage-flushing"
      "--enable-memory-pressure-signal"
      "--max-unused-resource-memory-usage-percentage=5"

      # Mobile-friendly features
      "--touch-events=enabled"
      "--enable-pinch"

      # Network optimization for mobile connections
      "--enable-quic"
      "--aggressive-cache-discard"
    ];
  };

  # Firefox configuration optimized for laptop use
  programs.firefox = {
    enable = true;
    profiles.default = {
      settings = {
        "widget.use-xdg-desktop-portal.file-picker" = 1;
        "media.ffmpeg.vaapi.enabled" = true;
        "dom.security.https_only_mode" = true;
        "privacy.trackingprotection.enabled" = true;

        # Battery optimization settings
        "media.autoplay.default" = 5; # Block autoplay
        "layers.acceleration.force-enabled" = true;
        "gfx.webrender.all" = true;
        "browser.sessionstore.interval" = 15000; # Reduce disk writes
      };
    };
  };
}
