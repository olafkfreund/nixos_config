{ ... }: {
  imports = [
    # Import common modules
    ../common/default.nix

    # Host-specific imports
    ../../hosts/hp/nixos/hypr_override.nix
    ../../home/desktop/sway/default.nix
    ../../home/desktop/sway/swayosd.nix
    ./private.nix
  ];

  # Fix Stylix Firefox profile warnings
  stylix.targets.firefox.profileNames = [ "default" ];

  # Use the new features system instead of multiple lib.mkForce calls
  features = {
    terminals = {
      enable = true;
      alacritty = true;
      foot = true;
      wezterm = true;
      kitty = true;
      ghostty = false;
    };

    editors = {
      enable = true;
      cursor = false;
      neovim = true;
      vscode = false;
      zed = false;
      windsurf = false;
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
      obsidian = false;
      swaylock = true;
      flameshot = true;
      kooha = true;
      remotedesktop = true;
      walker = false;

      # Communication and media
      obs = true;
      evince = true;
      kdeconnect = true;
      slack = false;
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
  };

  # Host-specific Sway configuration
  wayland.windowManager.sway = {
    extraConfig = ''
      output HEADLESS-1 pos 0 0 res 3840x2160
      # output HDMI-0 pos 0 0 res 3840x2160
      #output DP-2 pos 0 0 res 3840x2160
      # output DP-4 pos 0 0 res 3840x2160
    '';
  };
}
