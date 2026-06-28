{ config
, lib
, pkgs
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
    ../../home/media/reddit.nix
    ../../home/applications/voice-input.nix
    ./private.nix
  ];

  # Voice dictation → Groq Whisper-Large-v3 (~200-400 ms, cheap, accurate).
  # API key is decrypted by agenix to /run/agenix/api-groq (mode 0644 via
  # modules/secrets/api-keys.nix). Falls back to the local whisper-server
  # on p620:9300 if you flip back to backend = "local".
  programs.voice-input = {
    backend = "groq";
    apiKeyFile = "/run/agenix/api-groq";
  };

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
      # Shared extensions live in home/desktop/gnome/extensions.nix.
      # Only profile-specific additions go here.
      packages = with pkgs.gnomeExtensions;
        optionals (gnomeProfile == "laptop") [
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
      wave = true;
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
    # Antigravity IDE 2.0.1 — Google's rebranded Antigravity Desktop.
    # Local derivation in pkgs/antigravity-ide/. See pkgs/default.nix
    # for the rationale (upstream antigravity-nix is still on 1.x).
    pkgs.customPkgs.antigravity-ide
    # Antigravity Hub — Google's Antigravity desktop launcher (`antigravity-hub`).
    pkgs.customPkgs.antigravity-hub
    pkgs.customPkgs.kosli-cli
    pkgs.customPkgs.aurynk
    pkgs.wayfarer
    # FlyCrys — GTK4-native Claude Code GUI. Wraps the local `claude`
    # binary (installed via programs.claude-code.enable in home/default.nix).
    pkgs.customPkgs.flycrys

    # Google Antigravity Python SDK — Python env with `google.antigravity`
    # importable for building Gemini-powered AI agents. See
    # pkgs/google-antigravity-py/ for the platform-wheel install.
    pkgs.customPkgs.google-antigravity-py
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
