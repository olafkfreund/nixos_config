{ lib, ... }: {
  # Terminal app desktop entries
  programs.k9s.desktopEntry.enable = lib.mkForce true;
  programs.claude-code.desktopEntry.enable = lib.mkForce true;
  programs.neovim.desktopEntry.enable = lib.mkForce true;

  # Host-specific features configuration
  # This replaces all the individual lib.mkForce calls with a unified approach
  features = {
    # Program features
    programs = {
      obs.enable = true;
      kdeconnect.enable = true;
      slack.enable = true;
    };

    # Terminal features
    terminals = {
      foot.enable = true;
      wezterm.enable = true;
      kitty.enable = true;
      # alacritty.enable = false;
    };

    # Desktop environment features
    desktop = {
      sway.enable = false;
      zathura.enable = true;
      dunst.enable = true;
      rofi.enable = true;
      swaylock.enable = false;
      screenshots.flameshot.enable = true;
    };

    # Browser features
    browsers = {
      chrome.enable = true;
      firefox.enable = true;
      edge.enable = false;
      brave.enable = true;
      opera.enable = true;
    };

    # Editor features
    editors = {
      cursor.enable = true;
      neovim.enable = true;
      vscode.enable = true;
    };

    # CLI tools features
    cli = {
      bat.enable = true;
      direnv.enable = true;
      fzf.enable = true;
      lf.enable = true;
      starship.enable = true;
      yazi.enable = true;
      zoxide.enable = true;
    };

    # Terminal multiplexer features
    multiplexers = {
      tmux.enable = true;
      zellij.enable = true;
    };
  };
}
