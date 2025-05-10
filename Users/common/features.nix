{
  config,
  lib,
  ...
}:
with lib; {
  options.features = {
    terminals = {
      enable = mkEnableOption "Enable terminal emulators";
      alacritty = mkEnableOption "Enable Alacritty terminal";
      foot = mkEnableOption "Enable Foot terminal";
      wezterm = mkEnableOption "Enable Wezterm terminal";
      kitty = mkEnableOption "Enable Kitty terminal";
      ghostty = mkEnableOption "Enable Ghostty terminal";
    };

    editors = {
      enable = mkEnableOption "Enable editors";
      cursor = mkEnableOption "Enable Cursor editor";
      neovim = mkEnableOption "Enable Neovim editor";
      vscode = mkEnableOption "Enable VS Code editor";
      zed = mkEnableOption "Enable Zed editor";
      windsurf = mkEnableOption "Enable Windsurf editor";
    };

    browsers = {
      enable = mkEnableOption "Enable browsers";
      chrome = mkEnableOption "Enable Chrome browser";
      firefox = mkEnableOption "Enable Firefox browser";
      edge = mkEnableOption "Enable Edge browser";
      brave = mkEnableOption "Enable Brave browser";
      opera = mkEnableOption "Enable Opera browser";
    };

    desktop = {
      enable = mkEnableOption "Enable desktop applications";
      sway = mkEnableOption "Enable Sway window manager";
      hyprland = mkEnableOption "Enable Hyprland";
      dunst = mkEnableOption "Enable Dunst notifications";
      swaync = mkEnableOption "Enable SwayNC notifications";
      zathura = mkEnableOption "Enable Zathura PDF reader";
      rofi = mkEnableOption "Enable Rofi launcher";
      obsidian = mkEnableOption "Enable Obsidian notes";
      swaylock = mkEnableOption "Enable Swaylock";
      flameshot = mkEnableOption "Enable Flameshot screenshots";
      kooha = mkEnableOption "Enable Kooha screen recording";
      remotedesktop = mkEnableOption "Enable Remote Desktop";
      walker = mkEnableOption "Enable Walker";

      # Communication and media
      obs = mkEnableOption "Enable OBS Studio";
      evince = mkEnableOption "Enable Evince document viewer";
      kdeconnect = mkEnableOption "Enable KDE Connect";
      slack = mkEnableOption "Enable Slack";
      discord = mkEnableOption "Enable Discord";
      lanmouse = mkEnableOption "Enable LAN Mouse";
    };

    cli = {
      enable = mkEnableOption "Enable CLI tools";
      bat = mkEnableOption "Enable bat (cat alternative)";
      direnv = mkEnableOption "Enable direnv";
      fzf = mkEnableOption "Enable fzf fuzzy finder";
      lf = mkEnableOption "Enable lf file manager";
      starship = mkEnableOption "Enable starship prompt";
      yazi = mkEnableOption "Enable Yazi file manager";
      zoxide = mkEnableOption "Enable zoxide directory jumper";
      gh = mkEnableOption "Enable GitHub CLI";
      markdown = mkEnableOption "Enable markdown tools";
    };

    multiplexers = {
      enable = mkEnableOption "Enable terminal multiplexers";
      tmux = mkEnableOption "Enable Tmux";
      zellij = mkEnableOption "Enable Zellij";
    };

    gaming = {
      enable = mkEnableOption "Enable gaming applications";
      steam = mkEnableOption "Enable Steam";
    };
  };
}
