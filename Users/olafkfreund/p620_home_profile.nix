# P620 Home Configuration - Full Workstation Profile
# Uses full-workstation composition (developer + desktop-user)
{ lib, pkgs, config, ... }: {
  imports = [
    # Import common user configuration
    ../common/default.nix
    ./private.nix

    # Import both developer and desktop-user profiles
    ../../home/profiles/developer/default.nix
    ../../home/profiles/desktop-user/default.nix

    # Host-specific configurations
    ../../hosts/p620/nixos/env.nix
    ../../home/desktop/sway/default.nix
    ../../home/desktop/sway/swayosd.nix
    ../../home/games/steam.nix
  ];

  # Profile metadata
  meta.profile = {
    name = "full-workstation";
    type = "composition";
    description = "Full workstation combining development and desktop capabilities";
    combines = [ "developer" "desktop-user" ];
    host = "p620";
  };

  # Fix Stylix Firefox profile warnings
  stylix.targets.firefox.profileNames = [ "default" ];

  # Enable Walker launcher when feature flag is set
  desktop.walker.enable = config.features.desktop.walker;

  # P620-specific feature overrides
  features = {
    # Override desktop features for P620 (AMD workstation optimizations)
    desktop.quickshell = false; # Temporarily disabled - QML files missing

    # Full gaming support on primary workstation
    gaming = {
      enable = true;
      steam = true;
    };

    # All development languages and tools
    development = {
      enable = true;
      languages = true;
      workflow = true;
      productivity = true;
    };
  };

  # P620-specific packages
  home.packages = with pkgs; [
    # AMD-specific tools
    radeontop
    amdgpu_top

    # Workstation productivity
    # (Defined in profiles, can add P620-specific here)
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
      # Modern Wayland support
      "--enable-features=UseOzonePlatform,WaylandWindowDecorations"
      "--ozone-platform=wayland"
      "--disable-features=VizDisplayCompositor"

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

      # Fix zygote/sandbox error
      "--no-zygote"
      "--no-sandbox"
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
