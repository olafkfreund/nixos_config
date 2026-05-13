{ lib
, pkgs
, inputs
, ...
}: {
  imports = [
    ./profile.nix
    inputs.nix-openclaw.homeManagerModules.openclaw
  ];

  desktop.gnome.profile = "workstation";

  # Workstation-only terminal emulators
  features.terminals.kitty = true;
  features.terminals.ghostty = true;

  # Workstation-specific desktop flags
  features.desktop.obsidian = true;
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

  # Claude Code statusline with Gruvbox Dark theme
  programs.claude-powerline = {
    enable = true;
    theme = "custom";
    style = "powerline";
  };

  # OpenClaw — personal AI assistant gateway (systemd user service).
  # The wrapper reads /run/agenix/api-gemini at runtime and exports the contents
  # as $GEMINI_API_KEY (see nix-openclaw config.nix wrapper logic). OpenClaw
  # honours GEMINI_API_KEY as the Google provider fallback per
  # docs.openclaw.ai/providers/google, so no models.providers.google.apiKey is
  # set declaratively — keeps the key out of the Nix store.
  programs.openclaw = {
    enable = true;
    environment.GEMINI_API_KEY = "/run/agenix/api-gemini";
    config.agents.defaults.model = {
      primary = "google/gemini-3.1-pro-preview";
      # Fall back to Flash on watchdog timeout — the agent harness sends ~26
      # tools + ~20 skills in the initial prompt, and 3.1-pro-preview's
      # first-token latency frequently exceeds the gateway's idle watchdog.
      # Flash (1M ctx, reasoning) starts streaming fast and keeps the agent
      # responsive when 3.1 stalls.
      fallbacks = [ "google/gemini-2.5-flash" ];
    };

    # Expose plugin CLIs on the user's interactive PATH (off by default). The
    # gateway wrapper has them either way; this is so `gog auth credentials`
    # and `gog auth add …` (one-time browser-based OAuth) can be run from a
    # normal shell after deploy.
    exposePluginPackages = true;

    # Bundled plugins. Each puts its CLI on the gateway wrapper's PATH so the
    # already-loaded matching `gog` / `summarize` / `qmd` skills can call it.
    # `goplaces` is defaultEnable=true upstream — no need to list it here.
    bundledPlugins = {
      # Google Workspace — Gmail, Calendar, Drive, Contacts, Sheets, Docs.
      # OAuth setup is one-time and interactive (browser flow): after deploy run
      #   gog auth credentials /path/to/client_secret.json    # from GCP console
      #   gog auth add olaf@freundcloud.com --services gmail,calendar,drive,contacts,docs,sheets
      gogcli.enable = true;

      # URL / PDF / YouTube summarisation — useful for inbox triage and reading.
      summarize.enable = true;

      # Local markdown KB search (Obsidian-friendly).
      qmd.enable = true;
    };
  };

  # Add an [Install] section to the openclaw-gateway user service so it auto-
  # starts at boot (the upstream nix-openclaw HM module deliberately omits it
  # so the gateway is opt-in). Combined with `users.users.olafkfreund.linger
  # = true` at the system level, this means heartbeats / scheduled agent runs
  # keep working even when no shell session is active.
  systemd.user.services.openclaw-gateway.Install.WantedBy = [ "default.target" ];

  # Workstation-specific additional packages
  home.packages = [
    # Newelle — AI Virtual Assistant (GTK4/Libadwaita)
    pkgs.customPkgs.newelle

    # Glim — GitLab CI/CD TUI monitoring
    pkgs.glim
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
