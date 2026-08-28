{ config, lib, pkgs, ... }:
# DankMaterialShell (DMS) login sessions.
#
# niri session split: DMS hardcodes niri's default ~/.config/niri/config.kdl as
# the file it inspects/edits and ignores NIRI_CONFIG, so config.kdl IS the
# session's config (carrying the dms/*.kdl includes). See home/desktop/wayland.
#
# Hyprland has no NIRI_CONFIG equivalent and needs no split — its single
# hyprland.lua starts DMS directly.
#
# labwc, mango and the Noctalia shell were removed 2026-08-21 (unused), and
# with them the second niri session and the ${DESK_SHELL:-noctalia} switch that
# let a session choose between two shells.
let
  inherit (lib) mkEnableOption mkIf optional;
  cfg = config.desktop.dmsShell;

  niriDmsLauncher = pkgs.writeShellScript "niri-dms-session" ''
    export NIRI_CONFIG="$HOME/.config/niri/config.kdl"
    exec niri-session
  '';



  hyprlandLauncher = pkgs.writeShellScript "hyprland-dms-session" ''
    export DESK_SHELL="dms run"
    exec ${config.programs.hyprland.package}/bin/start-hyprland
  '';

  # services.displayManager.sessionPackages requires passthru.providedSessions to
  # match the .desktop basename.
  mkSession = { name, label, comment, exec, desktopNames ? name }:
    (pkgs.writeTextFile {
      name = "${name}-wayland-session";
      destination = "/share/wayland-sessions/${name}.desktop";
      text = ''
        [Desktop Entry]
        Name=${label}
        Comment=${comment}
        Exec=${exec}
        Type=Application
        DesktopNames=${desktopNames}
      '';
    }).overrideAttrs (_: { passthru.providedSessions = [ name ]; });

  niriDmsSession = mkSession { name = "niri-dms"; label = "Niri (DankMaterialShell)"; comment = "Niri with the DankMaterialShell desktop shell"; exec = "${niriDmsLauncher}"; };
  # DesktopNames stays "Hyprland" (not the session name): xdg-desktop-portal-hyprland
  # declares UseIn=wlroots;Hyprland;... and would not bind for "hyprland-dms",
  # breaking ScreenCast/Screenshot in this session.
  hyprlandDmsSession = mkSession { name = "hyprland-dms"; label = "Hyprland (DankMaterialShell)"; comment = "Hyprland with the DankMaterialShell desktop shell"; exec = "${hyprlandLauncher}"; desktopNames = "Hyprland"; };

  dmsSessions =
    [ niriDmsSession ]
    ++ optional config.desktop.hyprland.enable hyprlandDmsSession;
in
{
  options.desktop.dmsShell.enable =
    mkEnableOption "DankMaterialShell as selectable login sessions per WM (alongside Noctalia)";

  config = mkIf cfg.enable {
    programs.dms-shell = {
      enable = true;
      # The unit ships with the package (linked); the DMS niri session starts it on
      # demand. NOT wantedBy graphical-session.target (systemd.enable = false) so
      # it never auto-starts inside the Noctalia session.
      systemd.enable = false;
      # Off unless something asks for it: with no consumer for the matugen
      # output, installing it buys a dependency and nothing else. mkDefault so
      # features.themeOwner can turn it on for the host that does consume it.
      enableDynamicTheming = lib.mkDefault false;
    };

    # DMS sessions + the Noctalia shadow of niri.desktop. sessionPackages registers
    # the DMS entries; environment.systemPackages lands every .desktop in
    # /run/current-system/sw/share/wayland-sessions, where greetd greeters
    # (dms-greeter) actually look — sessionPackages alone does
    # not populate that dir on NixOS. The niri shadow uses hiPrio so it wins the
    # collision with niri-flake's stock niri.desktop in that dir.
    services.displayManager.sessionPackages = dmsSessions;
    environment.systemPackages = dmsSessions;
  };
}
