{ lib
, pkgs
, inputs
, ...
}: {
  imports = [
    ./profile.nix
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

  # Enable zellij on workstation (not on laptop for battery reasons)
  features.multiplexers.zellij = false;

  # GitLab runner enabled on the workstation (AC-powered)
  development.gitlab.runner.enable = true;

  # AI-powered shell command suggestions (Ctrl+G)
  programs.zshAiCmd = {
    enable = true;
    triggerKey = "^G";
    debug = false;
  };

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

  # Claude Code statusline with Gruvbox Dark theme
  programs.claude-powerline = {
    enable = true;
    theme = "custom";
    style = "powerline";
  };

  # Workstation-specific additional packages
  home.packages = [
    # Newelle — AI Virtual Assistant (GTK4/Libadwaita)
    pkgs.customPkgs.newelle

    # Glim — GitLab CI/CD TUI monitoring
    pkgs.glim

    # gnome-quick-web-apps — GTK4 web-app manager (PWA install, scope
    # confinement, CEF rendering). Native GNOME alternative to
    # cosmic-utils/web-apps.
    inputs.gnome-quick-web-apps.packages.${pkgs.system}.default
  ];

  # Optional: Add additional packages to the Windsurf environment
  editor.windsurf.settings = {
    theme = "gruvbox";
  };

  # P620 Chrome — Modern flags for AMD GPU systems
  programs.chromium = {
    package = lib.mkForce pkgs.google-chrome;
    commandLineArgs = lib.mkForce [
      "--enable-features=UseOzonePlatform,WaylandWindowDecorations,WebRTCPipeWireCapturer,WebUIDarkMode"
      "--ozone-platform=wayland"
      "--disable-features=VizDisplayCompositor"
      "--force-dark-mode"
      "--use-gl=desktop"
      "--enable-gpu-rasterization"
      "--enable-zero-copy"
      "--ignore-gpu-blocklist"
      "--disable-gpu-driver-bug-workarounds"
      "--enable-accelerated-2d-canvas"
      "--enable-accelerated-video-decode"
      "--use-vulkan"
      "--enable-quic"
      "--enable-tcp-fast-open"
      "--aggressive-cache-discard"
      "--process-per-site"
      "--max_old_space_size=4096"
      "--memory-pressure-off"
    ];
  };
}
