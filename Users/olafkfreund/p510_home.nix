{
  inputs,
  lib,
  ...
}: {
  imports = [
    # Import common modules
    ../common/default.nix

    # Host-specific imports
    ../../home/default.nix
    ../../hosts/p510/nixos/hypr_override.nix
    ../../home/desktop/sway/default.nix
    ../../home/desktop/sway/swayosd.nix
    ./private.nix
  ];

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
      sway = false;
      dunst = false;
      swaync = true;
      zathura = true;
      rofi = true;
      obsidian = false;
      swaylock = true;
      flameshot = true;
      kooha = true;
      remotedesktop = true;
      walker = true;

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
      zellij = false;
    };

    gaming = {
      enable = false;
      steam = false;
    };
  };

  # Host-specific Sway configuration
  wayland.windowManager.sway = {
    extraConfig = ''
      output DP-2 pos 0 0 res 3840x2160
    '';
  };
}
