{ lib
, pkgs
, config
, ...
}:
let
  vars = import ../../hosts/razer/variables.nix { };
in
{
  imports = [
    # Import common modules
    ../common/default.nix

    # Host-specific imports
    ../../home/default.nix
    ../../home/desktop/sway/default.nix
    ../../home/desktop/sway/swayosd.nix
    ../../home/games/steam.nix
    ../../hosts/razer/nixos/env.nix
    ./private.nix
  ];

  # Fix Stylix Firefox profile warnings
  stylix.targets.firefox.profileNames = [ "default" ];

  # Enable Walker launcher when feature flag is set
  desktop.walker.enable = config.features.desktop.walker;

  # GNOME desktop environment (optional - can be enabled/disabled)
  desktop.gnome = {
    enable = false; # Set to true to enable GNOME
    theme = {
      enable = true;
      variant = "dark";
    };
    extensions = {
      enable = true;
      packages = with pkgs.gnomeExtensions; [
        # Laptop-optimized extensions
        dash-to-dock
        appindicator
        battery-threshold # Battery management
        caffeine # Prevent sleep
        clipboard-indicator
      ];
    };
    apps = {
      enable = true;
      packages = with pkgs; [
        # Essential GNOME apps for laptop
        gnome-power-manager
        gnome-system-monitor
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
      kitty = false;
      ghostty = false;
    };

    editors = {
      enable = true;
      cursor = true;
      neovim = true;
      vscode = true;
      zed = true;
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
      sway = true;
      dunst = false;
      swaync = true;
      zathura = true;
      rofi = true;
      obsidian = true;
      swaylock = true;
      flameshot = true;
      kooha = true;
      remotedesktop = true;
      walker = true; # Re-enabled with Stylix integration

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
      zellij = true;
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

  # Host-specific Windsurf configuration
  editor.windsurf.extraPackages = with pkgs; [
    nixpkgs-fmt
    nil
  ];

  editor.windsurf.settings = {
    theme = lib.removePrefix "gruvbox-" vars.theme.scheme;
  };

  # Chrome with GPU completely disabled for stability
  programs.chromium = {
    commandLineArgs = lib.mkForce [
      "--enable-features=UseOzonePlatform"
      "--ozone-platform=wayland"
      "--disable-features=VizDisplayCompositor"
      # "--disable-gpu"
    ];
  };
}
