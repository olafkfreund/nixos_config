{ config
, lib
, pkgs
, antigravity-nix
, ...
}:
let
  inherit (lib) mkDefault optionals;
  gnomeProfile = config.desktop.gnome.profile;
in
{
  imports = [
    ../common/default.nix
    ../../home/default.nix
    ../../home/games/steam.nix
    ./private.nix
  ];

  # Terminal app desktop entries
  programs.k9s.desktopEntry.enable = lib.mkForce true;
  programs.claude-code.desktopEntry.enable = lib.mkForce true;
  programs.neovim.desktopEntry.enable = lib.mkForce true;

  # GNOME desktop environment.
  # desktop.gnome.profile is declared in home/desktop/gnome/host-profile.nix
  # (imported transitively via home/desktop/gnome/default.nix).
  # Per-host stubs set the profile value; this file reads it to gate
  # profile-conditional extension picks.
  desktop.gnome = {
    enable = true;
    theme = {
      enable = true;
      variant = "dark";
    };
    extensions = {
      enable = true;
      packages = with pkgs.gnomeExtensions;
        [
          # Extensions shared by both interactive profiles
          dash-to-dock
          appindicator
          caffeine
          clipboard-indicator
        ]
        ++ optionals (gnomeProfile == "workstation") [
          vitals
          blur-my-shell
        ]
        ++ optionals (gnomeProfile == "laptop") [
          battery-health-charging
        ];
    };
    apps = {
      enable = true;
      packages = with pkgs; [
        gnome-tweaks
        dconf-editor
      ];
    };
    keybindings.enable = true;
  };

  features = {
    terminals = {
      enable = true;
      alacritty = true;
      foot = true;
      wezterm = true;
      # kitty/ghostty: workstation (p620) only — defaults off; stub overrides
      kitty = mkDefault false;
      ghostty = mkDefault false;
      warp = true;
    };

    editors = {
      enable = true;
      cursor = true;
      neovim = true;
      vscode = true;
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
      zathura = true;
      # obsidian: p620 enables; razer keeps off (#370 electron-39 breakage)
      obsidian = mkDefault false;
      # flameshot: razer enables; p620 keeps off (Wayland multi-monitor issues)
      flameshot = mkDefault false;
      waylandScreenshots = mkDefault false;
      kooha = true;
      remotedesktop = true;
      obs = true;
      evince = true;
      kdeconnect = false;
      slack = true;
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
      # zellij: razer enables it; p620 does not
      zellij = mkDefault false;
    };

    gaming = {
      enable = true;
      steam = true;
    };

    development = {
      enable = true;
      languages = true;
      workflow = true;
      productivity = true;
    };
  };

  # GitLab: runner disabled by default (battery savings on laptop).
  # p620 stub overrides runner.enable = true.
  development.gitlab = {
    enable = true;
    runner.enable = mkDefault false;
    fluxcd.enable = true;
    ciLocal.enable = true;
  };

  # Proton applications suite (identical across interactive hosts)
  programs.proton = {
    enable = true;
    vpn.enable = true;
    pass.enable = true;
    mail.enable = true;
    authenticator.enable = true;
  };

  # Packages common to all interactive (non-headless) hosts
  home.packages = [
    antigravity-nix.packages.${pkgs.stdenv.hostPlatform.system}.google-antigravity-no-fhs
    pkgs.customPkgs.kosli-cli
    pkgs.customPkgs.aurynk
    pkgs.wayfarer
  ];

  # Windsurf LSP/formatter packages (identical across interactive hosts)
  editor.windsurf.extraPackages = with pkgs; [
    nixpkgs-fmt
    nil
  ];

  # Firefox (identical across interactive hosts)
  programs.firefox = {
    enable = true;
    profiles.default = {
      settings = {
        "widget.use-xdg-desktop-portal.file-picker" = 1;
        "media.ffmpeg.vaapi.enabled" = true;
      };
    };
  };
}
