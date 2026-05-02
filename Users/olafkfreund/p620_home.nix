{ lib
, pkgs
, ...
}: {
  imports = [ ./profile.nix ];

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
