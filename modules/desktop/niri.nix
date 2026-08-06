{ config, lib, pkgs, ... }:
# niri — scrollable-tiling Wayland compositor, exposed as a selectable login
# session. The niri-flake NixOS module (programs.niri) is wired in flake.nix;
# this feature module just turns it on with the nixpkgs package and registers
# the session. Shell/keybind refinement (Noctalia) lands in a later phase.
let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.desktop.niri;
in
{
  options.desktop.niri.enable =
    mkEnableOption "niri scrollable-tiling Wayland compositor (selectable login session)";

  config = lib.mkMerge [
    # Pin the package unconditionally, NOT inside `mkIf cfg.enable`. Hosts that
    # never enable the session still evaluate programs.niri.package, because the
    # home-manager profile generates xdg.configFile."niri-config" and validates
    # it against the package. Left unpinned, those hosts fall back to
    # niri-flake's default niri-stable, which is a year old and still references
    # the removed `libdisplay-info_0_2` — so p510 failed to evaluate at all once
    # nixpkgs dropped it, while p620/razer were fine only because they enable
    # niri and so hit the pin below.
    { programs.niri.package = pkgs.niri; }

    (mkIf cfg.enable {
      # Use the nixpkgs niri package and skip niri-flake's binary cache, so we
      # don't add an extra trusted substituter or need the cache-then-enable
      # rebuild dance documented upstream.
      niri-flake.cache.enable = false;

      programs.niri.enable = true;

      # programs.niri installs share/wayland-sessions/niri.desktop automatically,
      # so greetd/GDM list "niri" at login. Minimal runtime deps for a usable
      # bare session before the Noctalia shell phase.
      environment.systemPackages = with pkgs; [
        xwayland-satellite # rootless Xwayland for niri
      ];
    })
  ];
}
