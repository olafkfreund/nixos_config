{
  inputs,
  lib,
  ...
}: {
  imports = [
    # Import common modules
    ../common/default.nix

    # Host-specific imports
    ../../hosts/dex5550/nixos/hypr_override.nix
    ../../home/desktop/sway/default.nix
    ../../home/desktop/sway/swayosd.nix
    ./private.nix
  ];

  # Use the new features system instead of multiple lib.mkForce calls
  features = {
    terminals = {
      enable = true;
      alacritty = false;
      foot = true;
      wezterm = false;
      kitty = false;
      ghostty = false;
    };

    editors = {
      enable = true;
      cursor = false;
      neovim = true;
      vscode = false;
      zed = false;
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
      swaync = false;
      zathura = true;
      rofi = true;
      obsidian = false;
      swaylock = false;
      flameshot = true;
      kooha = true;
      remotedesktop = true;
      walker = true;

      # Communication and media
      obs = false;
      evince = true;
      kdeconnect = false;
      slack = false;
      discord = false;
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
      output DP-1 pos 0 0 res 3840x2160
    '';
  };
}
