{ config
, lib
, ...
}:
with lib; let
  cfg = config.features;
in
{
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
      editor = {
        cursor.enable = cfg.editors.cursor;
        neovim.enable = cfg.editors.neovim;
        vscode.enable = cfg.editors.vscode;
        zed-editor.enable = cfg.editors.zed;
        windsurf.enable = cfg.editors.windsurf;
      };
    })

    # Browser implementations
    (mkIf cfg.browsers.enable {
      browsers = {
        chrome.enable = cfg.browsers.chrome;
        firefox.enable = cfg.browsers.firefox;
        edge.enable = cfg.browsers.edge;
        brave.enable = cfg.browsers.brave;
        opera.enable = cfg.browsers.opera;
      };
    })

    # Desktop implementations
    (mkIf cfg.desktop.enable {
      desktop = {
        zathura.enable = cfg.desktop.zathura;
        obsidian.enable = cfg.desktop.obsidian;
        remotedesktop.enable = cfg.desktop.remotedesktop;
        screenshots = {
          flameshot.enable = cfg.desktop.flameshot;
          wayland.enable = cfg.desktop.waylandScreenshots;
          kooha.enable = cfg.desktop.kooha;
        };
      };

      # Communication and media apps
      programs = {
        obs.enable = cfg.desktop.obs;
        evince.enable = cfg.desktop.evince;
        kdeconnect.enable = cfg.desktop.kdeconnect;
        slack.enable = cfg.desktop.slack;
      };

      # File managers
      desktop.vicinae.enable = cfg.desktop.vicinae;
    })

    # CLI tool implementations
    (mkIf cfg.cli.enable {
      cli = {
        bat.enable = cfg.cli.bat;
        direnv.enable = cfg.cli.direnv;
        fzf.enable = cfg.cli.fzf;
        lf.enable = cfg.cli.lf;
        starship.enable = cfg.cli.starship;
        yazi.enable = cfg.cli.yazi;
        zoxide.enable = cfg.cli.zoxide;
        markdown.enable = cfg.cli.markdown;
        versioncontrol.gh.enable = cfg.cli.gh;
      };
    })

    # Terminal multiplexer implementations
    (mkIf cfg.multiplexers.enable {
      multiplexer = {
        tmux.enable = cfg.multiplexers.tmux;
        zellij.enable = cfg.multiplexers.zellij;
      };
    })

    # Gaming implementations
    (mkIf cfg.gaming.enable {
      # Import Steam config if enabled
    })

    # Development implementations - packages and configurations only
    (mkIf cfg.development.enable {
      # Development modules are imported at the top level in imports.nix
    })
  ];
}
