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

  config = mkIf cfg.enable {
    # Use the nixpkgs niri package and skip niri-flake's binary cache, so we
    # don't add an extra trusted substituter or need the cache-then-enable
    # rebuild dance documented upstream.
    niri-flake.cache.enable = false;

    programs.niri = {
      enable = true;
      package = pkgs.niri;
    };

    # programs.niri installs share/wayland-sessions/niri.desktop automatically,
    # so greetd/GDM list "niri" at login. Minimal runtime deps for a usable
    # bare session before the Noctalia shell phase.
    environment.systemPackages = with pkgs; [
      xwayland-satellite # rootless Xwayland for niri
    ];
  };
}
