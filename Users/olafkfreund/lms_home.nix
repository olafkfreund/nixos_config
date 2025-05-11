{
  inputs,
  lib,
  ...
}: {
  imports = [
    # Import common modules
    ../common/default.nix

    # Host-specific imports
    ../../hosts/lms/nixos/hypr_override.nix
    ../../home/desktop/sway/default.nix
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
      windsurf = false;
    };

    browsers = {
      enable = true;
      chrome = true;
      firefox = false;
      edge = false;
      brave = false;
      opera = false;
    };

    desktop = {
      enable = true;
      sway = true;
      dunst = true;
      swaync = false;
      zathura = true;
      rofi = true;
      obsidian = false;
      swaylock = false;
      flameshot = false;
      kooha = false;
      remotedesktop = false;
      walker = false;

      # Communication and media
      obs = false;
      evince = false;
      kdeconnect = false;
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
}
