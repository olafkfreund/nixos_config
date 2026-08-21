{ lib
, pkgs
, inputs
, ...
}:
{
  imports = [
    ./profile.nix
    ../../home/desktop/wayland # niri + Hyprland sessions and DMS theming
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

  # gnome-quick-web-apps — GTK4 web-app manager (PWA install, scope
  # confinement, CEF rendering). Native GNOME alternative to
  # cosmic-utils/web-apps.
  home.packages = [
    inputs.gnome-quick-web-apps.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];

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

  # No windsurf `theme` setting: the value it derived was never a real
  # Windsurf theme id (that needs an installed extension), so it wrote a
  # no-op. Windsurf uses its own dark default.

  # Razer Chrome — GPU completely disabled for stability on Optimus hybrid
  programs.chromium = {
    commandLineArgs = lib.mkForce [
      "--enable-features=UseOzonePlatform"
      "--ozone-platform=wayland"
      "--disable-features=VizDisplayCompositor"
    ];
  };
}
