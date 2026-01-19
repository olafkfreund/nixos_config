{ lib
, pkgs
, vicinae
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
    ../../home/games/steam.nix
    ./private.nix

    # Vicinae spatial file manager Home Manager module
    vicinae.homeManagerModules.default
  ];

  # Fix Stylix Firefox profile warnings
  stylix.targets.firefox.profileNames = [ "default" ];

  # Enable Walker launcher when feature flag is set

  # Terminal app desktop entries
  programs.k9s.desktopEntry.enable = lib.mkForce true;
  programs.claude-code.desktopEntry.enable = lib.mkForce true;
  programs.neovim.desktopEntry.enable = lib.mkForce true;

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
        # Laptop-optimized extensions
        dash-to-dock
        appindicator
        battery-health-charging # Battery management
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
      flameshot = true;
      kooha = true;
      remotedesktop = true;

      # Communication and media
      obs = true;
      evince = true;
      kdeconnect = true;
      slack = true;

      # File managers
      vicinae = true;
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

  # Additional packages
  home.packages = with pkgs; [
    # Kosli CLI - Compliance monitoring and DevOps workflows
    customPkgs.kosli-cli

    # Aurynk - Android Device Manager
    customPkgs.aurynk

    wayfarer # Screen recorder for GNOME/Wayland/pipewire
  ];

  # GitLab development configuration for Razer (mobile development)
  development.gitlab = {
    enable = true;
    runner.enable = false; # Disable runner on laptop for battery savings
    fluxcd.enable = true;
    ciLocal.enable = true;
  };

  # Enable Proton applications suite for Razer (mobile/laptop usage)
  programs.proton = {
    enable = true;
    vpn.enable = true;
    pass.enable = true;
    mail.enable = true;
    authenticator.enable = true;
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
