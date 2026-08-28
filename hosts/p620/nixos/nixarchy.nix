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

  # greetd already greets. nixarchy would otherwise enable SDDM, and two
  # display managers is not a working configuration. The existing greeter picks
  # the Omarchy session up from wayland-sessions like any other.
  programs.nixarchy.displayManager = false;

  # ~/.config/hypr/hyprland.lua is home-manager's here, so the seed keeps it and
  # Omarchy's own config is never installed. The Omarchy session entry is what
  # makes that work: it runs Hyprland with --config against Omarchy's file and
  # needs nothing of ours, so both desktops coexist.
  #
  # Plymouth is left alone deliberately: nixarchy only mkDefaults its own
  # splash, so stylix keeps this machine on 'stylix' with no mkForce needed.

  home-manager.users.olafkfreund = {
    imports = [ inputs.nixarchy.homeManagerModules.nixarchy ];
    programs.nixarchy.enable = true;
  };
}
