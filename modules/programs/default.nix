_: {
  imports = [
    # ./hyprland.nix
    ./1password.nix
    # ./steam.nix
    ./gnupg.nix
    ./dconf.nix
    ./nix-ld.nix
    ./firefox.nix
    ./wshowkeys.nix
    ./droidcam.nix
    ./yt-x.nix # Terminal YouTube browser
    ./chrome-pwa-icons.nix # Sync Chrome PWA icons into XDG hicolor (issue #397)
    ./claude-code-managed.nix # Read-only Claude Code baseline at /etc/claude-code (issue #398)
    ./claude-router-cli.nix # /use-ollama, /use-claude, /use-default — local Ollama vs cloud Claude per repo
    # ./streamcontroller.nix
    # ./thunar.nix
  ];
}
