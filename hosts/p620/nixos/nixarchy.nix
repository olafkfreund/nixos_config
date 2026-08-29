# Omarchy, vendored for NixOS.
#
# Same three settings as razer, and here for the same reasons -- this machine
# and that one are shaped alike: greetd through the DankMaterialShell greeter,
# niri and Hyprland both enabled, stylix owning the theme.
#
# Additive. The Omarchy session joins the existing entries and none of them
# change: greetd keeps greeting, stylix keeps the boot splash, and Hyprland
# sessions keep running the Hyprland this configuration chose.
{ inputs
, lib
, pkgs
, ...
}:
{
  # nixarchy-apply copies ~/.config/nixarchy/apps.nix to the flake root as
  # nixarchy-apps.nix and stops there -- a flake cannot read a file outside its
  # own tree, so the selection has to be copied in, and importing it is left to
  # us. razer has had this line since #1504; p620 never did, so the selection
  # landed in the flake and nothing read it. `dictation.enable = true` was
  # enabled in the menu, copied by apply, and built by nobody.
  imports = [
    inputs.nixarchy.nixosModules.nixarchy
    ../../../nixarchy-apps.nix
    ../../common/nixos/omarchy-input.nix
    ../../common/nixos/omarchy-workspaces.nix
  ];

  programs.nixarchy.enable = true;

  # Puts this user in the input group. Omarchy's shell reads the keyboard
  # device directly for its own key handling, which the group grants; without
  # it the session starts but never sees a keypress.
  programs.nixarchy.user = "olafkfreund";

  # nixarchy pins its own Hyprland and does not defer -- nixpkgs defines
  # programs.hyprland.package at mkDefault priority, so matching it would tie
  # rather than yield. desktop.hyprland already sets it here, so keep ours.
  programs.hyprland.package = lib.mkForce pkgs.hyprland;
  programs.hyprland.portalPackage = lib.mkForce pkgs.xdg-desktop-portal-hyprland;

  # Omarchy's SDDM greeter is the login manager. It replaced the
  # DankMaterialShell greetd greeter, which ran inside niri and went away
  # with niri and DMS. SDDM enumerates wayland-sessions, so GNOME stays
  # selectable alongside the Omarchy session.
  programs.nixarchy.displayManager = true;

  # ~/.config/hypr/hyprland.lua is home-manager's here, so the seed keeps it and
  # Omarchy's own config is never installed. The Omarchy session entry is what
  # makes that work: it runs Hyprland with --config against Omarchy's file and
  # needs nothing of ours, so both desktops coexist.
  #
  # Plymouth is left alone deliberately: nixarchy only mkDefaults its own
  # splash, so stylix keeps this machine on 'stylix' with no mkForce needed.

  # QtMultimedia for Omarchy shell plugins that want a camera preview
  # (io.github.kristoferlund.webcam). quickshell's wrapper injects only
  # qtdeclarative and qtwayland, so `import QtMultimedia` fails with "module is
  # not installed" and the plugin's whole Panel.qml refuses to load -- the bar
  # icon appears and clicking it does nothing.
  #
  # The wrapper *prefixes* NIXPKGS_QT6_QML_IMPORT_PATH rather than setting it,
  # so a value set here is preserved and searched. systemPackages is what puts
  # the multimedia backend under /run/current-system/sw/lib/qt-6/plugins, which
  # QT_PLUGIN_PATH already covers; only the QML path needs saying out loud.
  environment.systemPackages = [ pkgs.qt6.qtmultimedia ];
  environment.sessionVariables.NIXPKGS_QT6_QML_IMPORT_PATH =
    "${pkgs.qt6.qtmultimedia}/lib/qt-6/qml";

  home-manager.users.olafkfreund = {
    imports = [ inputs.nixarchy.homeManagerModules.nixarchy ];
    programs.nixarchy.enable = true;
  };
}
