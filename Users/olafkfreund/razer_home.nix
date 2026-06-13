{ lib
, pkgs
, inputs
, ...
}:
let
  vars = import ../../hosts/razer/variables.nix { };
in
{
  imports = [
    ./profile.nix
    ../../home/desktop/noctalia # Noctalia shell for niri/labwc sessions
  ];

  desktop.gnome.profile = "laptop";

  # gscratch — i3/Sway-style scratchpad for GNOME (testing on razer first).
  # Configure bindings via: gnome-extensions prefs scratchpad@wastedintelligence.com
  programs.gnome-shell = {
    enable = true;
    extensions = [
      { package = inputs.gscratch.packages.${pkgs.system}.default; }
    ];
  };

  # gnome-quick-web-apps — GTK4 web-app manager (PWA install, scope
  # confinement, CEF rendering). Native GNOME alternative to
  # cosmic-utils/web-apps.
  home.packages = [
    inputs.gnome-quick-web-apps.packages.${pkgs.system}.default
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

  # Windsurf theme derived from host variables (razer uses orange-desert variant)
  editor.windsurf.settings = {
    theme = lib.removePrefix "gruvbox-" vars.theme.scheme;
  };

  # Razer Chrome — GPU completely disabled for stability on Optimus hybrid
  programs.chromium = {
    commandLineArgs = lib.mkForce [
      "--enable-features=UseOzonePlatform"
      "--ozone-platform=wayland"
      "--disable-features=VizDisplayCompositor"
    ];
  };
}
