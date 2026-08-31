{ lib, pkgs, inputs, ... }:
# Nixarchy is the only Hyprland session offered at login.
#
# programs.hyprland is enabled by the nixarchy module itself, not by us, so
# turning off our own desktop.hyprland changed nothing: forcing that option
# false left programs.hyprland.enable true and hyprland-0.56.2 still in
# services.displayManager.sessionPackages, which is what SDDM enumerates.
#
# There is no option to drop one session. sessionPackages is a plain list many
# modules append to, so a filtered mkForce would have to read the value it
# defines, and a session-less repackage of the compositor is rejected outright:
# the option's own type demands `p.providedSessions != [ ]`.
#
# So the module is forced off and the parts of it Nixarchy actually needs are
# restated here. Everything below is copied from
# nixos/modules/programs/wayland/{hyprland,wayland-session}.nix minus the one
# line that registers the session. The `nix eval` diff of the whole system
# config before and after this file is empty apart from sessionPackages.
#
# Nixarchy's own session is untouched: it runs the Hyprland its flake pins, a
# different store path from pkgs.hyprland, launched with --config against
# Omarchy's own file.
let
  # The exact build nixarchy's session script invokes.
  hyprland = inputs.nixarchy.inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
in
{
  programs.hyprland.enable = lib.mkForce false;

  # uwsm: programs.hyprland pulled this in via withUWSM. The Omarchy session
  # runs under uwsm (wayland-session-envelope@start-hyprland.target), so it has
  # to stay on independently of the module.
  programs.uwsm.enable = true;

  # xdg.portal.configPackages carries hyprland-portals.conf, which is what
  # routes ScreenCast to the hyprland backend rather than wlr. Losing it is the
  # classic screen-sharing failure on this machine, so it is named explicitly.
  xdg.portal = {
    enable = true;
    extraPortals = [
      pkgs.xdg-desktop-portal-hyprland
      pkgs.xdg-desktop-portal-gtk
    ];
    configPackages = lib.mkDefault [ pkgs.hyprland ];
  };

  # From wayland-session.nix. All of these are mkDefault upstream and most are
  # also set by the GNOME session, but they are stated here so this file does
  # not depend on GNOME staying enabled.
  security.polkit.enable = true;
  security.pam.services.swaylock = { };
  programs.dconf.enable = lib.mkDefault true;
  programs.xwayland.enable = lib.mkDefault true;
  services.graphical-desktop.enable = true;
  services.xserver.desktopManager.runXdgAutostartIfNone = lib.mkDefault true;

  # The compositor binaries. programs.hyprland puts these in the system profile
  # via `environment.systemPackages = [ cfg.package ]`, and forcing the module
  # off without restating that line is what broke login on razer (#1566):
  # Omarchy's session script calls start-hyprland by absolute store path, but
  # start-hyprland then execs `Hyprland` BY NAME, so with nothing on PATH it
  # failed with
  #
  #   ERR from start-hyprland ]: failed to obtain hyprland version string (bad json)
  #   ERR from start-hyprland ]: fork(): execvp failed: No such file or directory
  #
  # and the unit died with result 'protocol'. hyprctl went missing with it,
  # which breaks every hyprctl-based omarchy command too. The SDDM greeter kept
  # working throughout because it invokes Hyprland by absolute path.
  #
  # This must be the Hyprland NIXARCHY pins, not pkgs.hyprland: they are
  # different versions (0.56.0 vs 0.56.2) and it is the nixarchy one the
  # session script runs, so a mismatched start-hyprland and compositor is
  # exactly what we would be reintroducing.
  environment.systemPackages = [ hyprland ];
  environment.pathsToLink = [ "/share/hypr" ];

  # cap_sys_nice, as programs.hyprland sets it. /run/wrappers/bin precedes the
  # system profile on PATH, so this is the Hyprland start-hyprland finds.
  security.wrappers.Hyprland = {
    owner = "root";
    group = "root";
    capabilities = "cap_sys_nice+ep";
    source = lib.getExe hyprland;
  };
}
