{ lib, ... }: {
  programs.obs.enable = lib.mkForce true;
  programs.kdeconnect.enable = lib.mkForce true;
  programs.slack.enable = lib.mkForce true;

  # Terminal app desktop entries
  programs.k9s.desktopEntry.enable = lib.mkForce true;
  programs.claude-code.desktopEntry.enable = lib.mkForce true;
  programs.neovim.desktopEntry.enable = lib.mkForce true;

  # Terminals
  # alacritty.enable = lib.mkForce true;
  foot.enable = lib.mkForce true;
  wezterm.enable = lib.mkForce true;
  kitty.enable = lib.mkForce true;

  # Desktop apps
  desktop.zathura.enable = lib.mkForce true;
  desktop.screenshots.flameshot.enable = lib.mkForce true;

  # Browsers
  browsers.chrome.enable = lib.mkForce true;
  browsers.firefox.enable = lib.mkForce true;
  browsers.edge.enable = lib.mkForce true;
  browsers.brave.enable = lib.mkForce true;
  browsers.opera.enable = lib.mkForce true;

  # Editors
  editor.cursor.enable = lib.mkForce true;
  editor.neovim.enable = lib.mkForce true;
  editor.vscode.enable = lib.mkForce true;

  # Shell tools
  cli.bat.enable = lib.mkForce true;
  cli.direnv.enable = true;
  cli.fzf.enable = true;
  cli.lf.enable = lib.mkForce true;
  cli.starship.enable = lib.mkForce true;
  cli.yazi.enable = lib.mkForce true;
  cli.zoxide.enable = lib.mkForce true;

  # Multiplexers
  multiplexer.tmux.enable = lib.mkForce true;
  multiplexer.zellij.enable = lib.mkForce false;
}
