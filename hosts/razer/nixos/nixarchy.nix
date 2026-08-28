# Omarchy, vendored for NixOS.
#
# Added to razer rather than p620 so the desktop this machine runs every day is
# not the one being experimented on. Everything here is additive: the Omarchy
# session appears alongside GNOME, niri, niri-dms, Hyprland, hyprland-dms and
# hyprland-uwsm, and none of those change.
#
# The three settings below are what `nix run github:olafkfreund/nixarchy#doctor`
# printed for this machine. Each is here for a reason it named:
{ inputs
, lib
, pkgs
, ...
}:
{
  # nixarchy-apply copies ~/.config/nixarchy/apps.nix to the flake root as
  # nixarchy-apps.nix and stops there -- a flake cannot read a file outside its
  # own tree, so the selection has to be copied in, and importing it is left to
  # you. Without this line the Omarchy menu appears to enable applications and
  # nothing is ever built. Only razer imports it; p620 has its own nixarchy and
  # would otherwise inherit this machine's selection.
  imports = [
    inputs.nixarchy.nixosModules.nixarchy
    ../../../nixarchy-apps.nix
    ../../common/nixos/omarchy-input.nix
    ../../common/nixos/omarchy-workspaces.nix
  ];

  programs.nixarchy.enable = true;

  # nixarchy pins its own Hyprland and does not defer -- nixpkgs defines
  # programs.hyprland.package at mkDefault priority, so matching that would tie
  # rather than yield. This machine already sets it through desktop.hyprland,
  # so keep ours; anything from 0.55 satisfies Omarchy, and this is 0.56.2.
  programs.hyprland.package = lib.mkForce pkgs.hyprland;
  programs.hyprland.portalPackage = lib.mkForce pkgs.xdg-desktop-portal-hyprland;

  # greetd already greets, through the DankMaterialShell greeter. nixarchy
  # would otherwise enable SDDM, and two display managers is not a working
  # configuration. With this off, the existing greeter simply picks the Omarchy
  # session up from wayland-sessions like any other.
  programs.nixarchy.displayManager = false;

  # ~/.config/hypr/hyprland.lua is managed by home-manager here, so the seed
  # keeps it and Omarchy's own config is never installed. That is what the
  # Omarchy session entry is for: it runs Hyprland with --config against
  # Omarchy's hyprland.lua and needs no file of ours, so both desktops work.
  #
  # Plymouth is left alone deliberately: nixarchy only mkDefaults its own
  # splash, so stylix keeps this machine on 'stylix' with no mkForce needed.

  home-manager.users.olafkfreund = {
    imports = [ inputs.nixarchy.homeManagerModules.nixarchy ];
    programs.nixarchy.enable = true;
  };
}
