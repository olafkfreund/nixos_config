{ lib, pkgs, inputs, ... }:
# TRIAL since 2026-09-23 (#2003), p620 and razer only: run the Hyprland main
# commit hyprflip's nightly CI last built and tested (its flake.lock), not
# nixarchy's tip of main. The compositor and the hyprflip plugins then always
# match, and come prebuilt from hyprland.cachix.org / nixarchy.cachix.org.
# p510 and nixarchy itself are untouched: nixarchy.inputs.hyprland (/main, the
# aquamarine fix) still decides their Hyprland.
#
# Updating: `nix flake update hyprflip` moves these hosts' Hyprland (to the last
# green night); `nix flake update nixarchy` no longer does.
#
# The session launcher, the SDDM greeter and omarchy-sole-hyprland.nix (PATH,
# cap_sys_nice wrapper) all read programs.hyprland.package, so this one line
# moves every one of them together -- the #1566 mismatch cannot come back.
#
# Switch back:
#   1. drop this import from hosts/p620/nixos/nixarchy.nix and
#      hosts/razer/nixos/nixarchy.nix;
#   2. flake.nix: restore `inputs.hyprland.follows = "nixarchy/hyprland";` on
#      the hyprflip input, then `nix flake lock`;
#   3. hosts/p620/nixos/nixarchy.nix: delete programs.hyprflip.package and
#      hy3Package (the module then builds against nixarchy's Hyprland);
#   4. delete this file.
{
  # mkForce: nixarchy sets this at normal priority and asks overrides to force.
  programs.hyprland.package = lib.mkForce
    inputs.hyprflip.inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
}
