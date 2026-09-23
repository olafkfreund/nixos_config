{ lib
, pkgs
, ...
}: {
  imports = [
    ./profile.nix
    ../../home/desktop/wayland # Hyprland session config
  ];

  desktop.gnome.profile = "workstation";

  # Workstation-only terminal emulators
  features.terminals.kitty = true;
  features.terminals.ghostty = true;

  # Workstation-specific desktop flags
  features.desktop.obsidian = true;
  features.desktop.aerion = true;
  features.desktop.waylandScreenshots = true;
  features.desktop.quickshell = true;

  # GitLab runner enabled on the workstation (AC-powered)
  development.gitlab.runner.enable = true;

  # AI-powered shell command suggestions (Ctrl+G). Off: it only worked by
  # exporting ANTHROPIC_API_KEY into every interactive shell, and bash's
  # flyline agent mode covers the same ground (#1751).
  programs.zshAiCmd.enable = false;

  # splashboard — terminal splash screen on shell startup + cd. User config
  # under ~/.splashboard/ (not nix-managed). Opt out per-shell with
  # SPLASHBOARD_SILENT=1 or globally with NO_SPLASHBOARD=1.
  programs.splashboard.enable = true;

  # gogcli-fed splashboard panels: Gmail unread, Google Tasks, Calendar events.
  # Account email — confirm/adjust if your Google account differs.
  programs.gogDashboard = {
    enable = true;
    account = "olaf@freundcloud.com";
  };

  # Claude Code statusline, themed from the base16 scheme.
  # theme/style dropped in #1159 — they only ever configured the removed
  # @owloops/claude-powerline npx wrapper, never the script actually in use.
  programs.claude-powerline.enable = true;

  # Workstation-specific additional packages
  home.packages = [
    # Glim — GitLab CI/CD TUI monitoring
    pkgs.glim

    # Omgato CLIs (streamdeck/keylight/camlink-ctl, omgato-panel), called by
    # name from the Omgato Omarchy bar widget.
    pkgs.customPkgs.omgato

    # Libation — Audible library downloader/DRM-decrypter. Books location is set
    # to /mnt/media/Media/Audiobooks (P510 ABS library, NFS-mounted here) so
    # decrypted m4b land straight in Audiobookshelf. nixpkgs wraps it without
    # webkitgtk, so the Avalonia login/setup WebView crashes with "Unable to
    # initialize GTK"; add the gtk3-ABI webkit (4.1) back to its runtime libs.
    (pkgs.libation.overrideAttrs (old: {
      dotnetRuntimeDeps = (old.dotnetRuntimeDeps or [ ]) ++ [ pkgs.webkitgtk_4_1 ];
    }))
  ];

  # Omgato Stream Deck daemons, bound to the graphical session so they die at
  # logout and start fresh at login with the new session's environment (#1978).
  # Names match upstream's: the Omgato bar widget starts/stops them by name.
  systemd.user.services =
    let
      mkDeckUnit = description: args: {
        Unit = {
          Description = description;
          PartOf = [ "graphical-session.target" ];
          After = [ "graphical-session.target" ];
          StartLimitIntervalSec = 60;
          StartLimitBurst = 20;
        };
        Service = {
          ExecStart = "${pkgs.customPkgs.omgato}/bin/streamdeck-ctl ${args}";
          Restart = "on-failure";
          RestartSec = 2;
        };
        Install.WantedBy = [ "graphical-session.target" ];
      };
    in
    {
      streamdeck-ctl-deck = mkDeckUnit "Stream Deck (Mk2/XL/Mini) daemon" "deck run";
      streamdeck-ctl = mkDeckUnit "Stream Deck Pedal daemon" "pedal run";
    };

  # P620 Chrome — Modern flags for AMD GPU systems
  programs.chromium = {
    package = lib.mkForce pkgs.google-chrome;
    commandLineArgs = lib.mkForce [
      "--enable-features=UseOzonePlatform,WaylandWindowDecorations,WebRTCPipeWireCapturer,WebUIDarkMode"
      "--ozone-platform=wayland"
      "--force-dark-mode"
      # ANGLE-on-OpenGL (Mesa/AMD). Replaces the removed --use-gl=desktop;
      # do NOT disable VizDisplayCompositor — that kills GPU compositing and WebGL.
      "--use-angle=gl"
      "--enable-gpu-rasterization"
      "--enable-zero-copy"
      "--enable-quic"
      # Do NOT re-add --process-per-site (#1776): it puts every frame of one
      # site in a single renderer, so one core serves the whole of a heavy SPA
      # and typing stalls for minutes. --aggressive-cache-discard and
      # --memory-pressure-off contradict each other, and --max_old_space_size
      # is a V8 flag Chrome ignores unless passed through --js-flags.
    ];
  };
}
