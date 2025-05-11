{
  config,
  lib,
  ...
}:
with lib; let
  cfg = config.features;
in {
  imports = [
    ./features.nix
  ];

  config = mkMerge [
    # Terminal implementations
    (mkIf cfg.terminals.enable {
      alacritty.enable = cfg.terminals.alacritty;
      foot.enable = cfg.terminals.foot;
      wezterm.enable = cfg.terminals.wezterm;
      kitty.enable = cfg.terminals.kitty;
      ghostty.enable = cfg.terminals.ghostty;
    })

    # Editor implementations
    (mkIf cfg.editors.enable {
      editor.cursor.enable = cfg.editors.cursor;
      editor.neovim.enable = cfg.editors.neovim;
      editor.vscode.enable = cfg.editors.vscode;
      editor.zed-editor.enable = cfg.editors.zed;
      editor.windsurf.enable = cfg.editors.windsurf;
    })

    # Browser implementations
    (mkIf cfg.browsers.enable {
      browsers.chrome.enable = cfg.browsers.chrome;
      browsers.firefox.enable = cfg.browsers.firefox;
      browsers.edge.enable = cfg.browsers.edge;
      browsers.brave.enable = cfg.browsers.brave;
      browsers.opera.enable = cfg.browsers.opera;
    })

    # Desktop implementations
    (mkIf cfg.desktop.enable {
      desktop.sway.enable = cfg.desktop.sway;
      desktop.dunst.enable = cfg.desktop.dunst;
      desktop.swaync.enable = cfg.desktop.swaync;
      desktop.zathura.enable = cfg.desktop.zathura;
      desktop.rofi.enable = cfg.desktop.rofi;
      desktop.obsidian.enable = cfg.desktop.obsidian;
      swaylock.enable = cfg.desktop.swaylock;
      desktop.screenshots.flameshot.enable = cfg.desktop.flameshot;
      desktop.screenshots.kooha.enable = cfg.desktop.kooha;
      desktop.remotedesktop.enable = cfg.desktop.remotedesktop;
      desktop.walker.enable = cfg.desktop.walker;

      # Communication and media apps
      programs.obs.enable = cfg.desktop.obs;
      programs.evince.enable = cfg.desktop.evince;
      programs.kdeconnect.enable = cfg.desktop.kdeconnect;
      programs.slack.enable = cfg.desktop.slack;
    })

    # CLI tool implementations
    (mkIf cfg.cli.enable {
      cli.bat.enable = cfg.cli.bat;
      cli.direnv.enable = cfg.cli.direnv;
      cli.fzf.enable = cfg.cli.fzf;
      cli.lf.enable = cfg.cli.lf;
      cli.starship.enable = cfg.cli.starship;
      cli.yazi.enable = cfg.cli.yazi;
      cli.zoxide.enable = cfg.cli.zoxide;
      cli.versioncontrol.gh.enable = cfg.cli.gh;
      cli.markdown.enable = cfg.cli.markdown;
    })

    # Terminal multiplexer implementations
    (mkIf cfg.multiplexers.enable {
      multiplexer.tmux.enable = cfg.multiplexers.tmux;
      multiplexer.zellij.enable = cfg.multiplexers.zellij;
    })

    # Gaming implementations
    (mkIf cfg.gaming.enable {
      # Import Steam config if enabled
    })
  ];
}
