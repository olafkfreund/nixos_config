{ config, lib, pkgs, ... }:
# DankMaterialShell (DMS) as extra selectable login sessions, one per WM we run
# (niri, labwc, mango), alongside the stock Noctalia sessions.
#
# niri session split (see home/desktop/noctalia): DMS hardcodes niri's default
# ~/.config/niri/config.kdl as the file it inspects/edits and ignores NIRI_CONFIG,
# so config.kdl IS the DMS session's config (carrying the dms/*.kdl includes), and
# the Noctalia config is moved to config-noctalia.kdl. Each niri launcher selects
# its file via NIRI_CONFIG. We also shadow niri-flake's stock niri.desktop with a
# hiPrio "Niri" session so the plain "Niri" entry keeps loading the Noctalia config
# rather than the DMS config.kdl.
#
# labwc/mango have no systemd session and no per-file config split here; their DMS
# entries just set DESK_SHELL="dms run" (the ${DESK_SHELL:-noctalia} switch in
# home/desktop/noctalia's labwc autostart / mango autostart_sh) so DMS launches
# instead of Noctalia. `dms run` is a fully supported DMS launch mode.
let
  inherit (lib) mkEnableOption mkIf optional hiPrio;
  cfg = config.desktop.dmsShell;

  niriDmsLauncher = pkgs.writeShellScript "niri-dms-session" ''
    export NIRI_CONFIG="$HOME/.config/niri/config.kdl"
    exec niri-session
  '';
  niriNoctaliaLauncher = pkgs.writeShellScript "niri-noctalia-session" ''
    export NIRI_CONFIG="$HOME/.config/niri/config-noctalia.kdl"
    exec niri-session
  '';
  labwcLauncher = pkgs.writeShellScript "labwc-dms-session" ''
    export DESK_SHELL="dms run"
    exec labwc
  '';
  mangoLauncher = pkgs.writeShellScript "mango-dms-session" ''
    export DESK_SHELL="dms run"
    exec mango
  '';

  # services.displayManager.sessionPackages requires passthru.providedSessions to
  # match the .desktop basename.
  mkSession = { name, label, comment, exec }:
    (pkgs.writeTextFile {
      name = "${name}-wayland-session";
      destination = "/share/wayland-sessions/${name}.desktop";
      text = ''
        [Desktop Entry]
        Name=${label}
        Comment=${comment}
        Exec=${exec}
        Type=Application
        DesktopNames=${name}
      '';
    }).overrideAttrs (_: { passthru.providedSessions = [ name ]; });

  niriDmsSession = mkSession { name = "niri-dms"; label = "Niri (DankMaterialShell)"; comment = "Niri with the DankMaterialShell desktop shell"; exec = "${niriDmsLauncher}"; };
  labwcDmsSession = mkSession { name = "labwc-dms"; label = "labwc (DankMaterialShell)"; comment = "labwc with the DankMaterialShell desktop shell"; exec = "${labwcLauncher}"; };
  mangoDmsSession = mkSession { name = "mango-dms"; label = "mango (DankMaterialShell)"; comment = "mango with the DankMaterialShell desktop shell"; exec = "${mangoLauncher}"; };

  # Shadow niri-flake's stock niri.desktop (which runs niri-session against the
  # default config.kdl — now the DMS config) so the plain "Niri" session stays
  # Noctalia, loading config-noctalia.kdl. hiPrio wins the wayland-sessions/
  # niri.desktop buildEnv collision with the niri package's own entry.
  niriNoctaliaSession = mkSession { name = "niri"; label = "Niri"; comment = "Niri scrollable-tiling compositor with the Noctalia shell"; exec = "${niriNoctaliaLauncher}"; };

  dmsSessions =
    [ niriDmsSession ]
    ++ optional config.desktop.labwc.enable labwcDmsSession
    ++ optional config.desktop.mangowm.enable mangoDmsSession;
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
      # Keep Stylix/Gruvbox for the trial; set true to let DMS drive matugen
      # Material You theming from the wallpaper instead.
      enableDynamicTheming = false;
    };

    # DMS sessions + the Noctalia shadow of niri.desktop. sessionPackages registers
    # the DMS entries; environment.systemPackages lands every .desktop in
    # /run/current-system/sw/share/wayland-sessions, where greetd greeters
    # (dms-greeter / noctalia-greeter) actually look — sessionPackages alone does
    # not populate that dir on NixOS. The niri shadow uses hiPrio so it wins the
    # collision with niri-flake's stock niri.desktop in that dir.
    services.displayManager.sessionPackages = dmsSessions;
    environment.systemPackages = dmsSessions ++ [ (hiPrio niriNoctaliaSession) ];
  };
}
