{ lib
, pkgs
, ...
}:
let
  vars = import ../../hosts/razer/variables.nix { };
in
{
  imports = [ ./profile.nix ];

  desktop.gnome.profile = "laptop";

  # Laptop: enable zellij (session management for mobile use)
  features.multiplexers.zellij = true;

  # Laptop: flameshot works fine on Razer (single-monitor Wayland)
  features.desktop.flameshot = true;

  # obsidian stays disabled — see #370 (electron-39 build broken upstream)

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
