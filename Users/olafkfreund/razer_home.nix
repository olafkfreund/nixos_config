{ lib
, pkgs
, inputs
, ...
}:
{
  imports = [
    ./profile.nix
    ../../home/desktop/wayland # Hyprland session config
  ];

  desktop.gnome.profile = "laptop";

  # razer runs no Ollama of its own, but both Neovim AI plugins default to
  # http://localhost:11434 — so minuet-ai (which fires on every InsertEnter)
  # and codecompanion were silently failing here while working fine on p620.
  # Both already read this variable; it was simply never set. p620 serves
  # Ollama on 0.0.0.0:11434 and is reachable from razer over the LAN.
  home.sessionVariables.OLLAMA_ENDPOINT = "http://p620:11434";

  # gscratch — i3/Sway-style scratchpad for GNOME (testing on razer first).
  # Configure bindings via: gnome-extensions prefs scratchpad@wastedintelligence.com
  programs.gnome-shell = {
    enable = true;
    extensions = [
      { package = inputs.gscratch.packages.${pkgs.stdenv.hostPlatform.system}.default; }
    ];
  };

  # Laptop: enable zellij (session management for mobile use)
  features.multiplexers.zellij = true;

  # Ghostty: profile.nix defaults this off ("workstation only"); razer wants
  # it too as the primary terminal alongside the existing wave/warp/foot/etc.
  features.terminals.ghostty = true;

  # Laptop: flameshot works fine on Razer (single-monitor Wayland)
  features.desktop.flameshot = true;

  features.desktop.aerion = true;

  # obsidian stays disabled — see #370 (electron-39 build broken upstream)

  # splashboard — terminal splash screen on shell startup + cd. Same as p620.
  programs.splashboard.enable = true;

  # gogcli-fed splashboard panels: Gmail unread, Google Tasks, Calendar events.
  programs.gogDashboard = {
    enable = true;
    account = "olaf@freundcloud.com";
  };

  # Razer Chrome — ANGLE on Vulkan. On this Intel + Mesa + Ozone/Wayland stack
  # ANGLE fails to import Wayland dmabufs, falls back to a slow path per surface,
  # and the page stutters while scrolling. `--use-angle=gl` was the old guess and
  # does NOT fix it: measured over a 25s Reddit session, buffer-import failures
  # were gl 1734, gl + --disable-gpu-memory-buffer-compositor-resources 1992,
  # vulkan 15, --ozone-platform=x11 0. None fell back to software.
  # x11 scores best but runs under XWayland, which breaks the PipeWire screen-share
  # portal (browser calls lose screen sharing), so vulkan is the deliberate pick.
  #
  # Chrome does NOT merge repeated --enable-features: the last occurrence wins and
  # silently discards the earlier ones. The nixpkgs wrapper passes its own
  # --enable-features=WaylandWindowDecorations ahead of these, so everything that
  # must stay on is restated here in a single flag.
  programs.chromium = {
    commandLineArgs = lib.mkForce [
      "--enable-features=UseOzonePlatform,WaylandWindowDecorations"
      "--ozone-platform=wayland"
      "--disable-features=VizDisplayCompositor"
      "--use-angle=vulkan"
      "--disable-smooth-scrolling"
    ];
  };
}
