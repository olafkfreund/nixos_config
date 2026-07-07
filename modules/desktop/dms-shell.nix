{ config, lib, pkgs, ... }:
# DankMaterialShell (DMS) as extra selectable login sessions, one per WM we run
# (niri, labwc, mango), alongside the stock Noctalia sessions. Each compositor's
# shell launch reads ${DESK_SHELL:-noctalia}: the stock session leaves it unset
# → Noctalia; the "(DankMaterialShell)" session sets it → DMS. Only one shell
# ever runs per session, so Noctalia and DMS never collide.
#
# niri has systemd session integration (graphical-session.target + env import),
# so its DMS session prefers the managed dms.service (doctor-clean, restart on
# failure, journald logs) and only falls back to a direct `dms run` spawn if the
# service can't start. labwc/mango launch bare (no systemd session), so their
# DMS sessions run `dms run` directly — a fully supported DMS launch mode.
#
# Pairs with the ${DESK_SHELL:-noctalia} switch in home/desktop/noctalia
# (niri spawn-at-startup, labwc autostart, mango autostart_sh).
let
  inherit (lib) mkEnableOption mkIf optional;
  cfg = config.desktop.dmsShell;

  # niri: try the managed service first (keeps `dms doctor` clean), fall back to
  # a direct spawn if graphical-session.target isn't ready.
  dmsNiriShell = pkgs.writeShellScript "dms-niri-shell" ''
    if systemctl --user start dms.service 2>/dev/null; then exit 0; fi
    exec dms run
  '';
  niriLauncher = pkgs.writeShellScript "niri-dms-session" ''
    export DESK_SHELL="${dmsNiriShell}"
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
  mkDmsSession = { name, label, exec }:
    (pkgs.writeTextFile {
      name = "${name}-wayland-session";
      destination = "/share/wayland-sessions/${name}.desktop";
      text = ''
        [Desktop Entry]
        Name=${label}
        Comment=${label} with the DankMaterialShell desktop shell
        Exec=${exec}
        Type=Application
        DesktopNames=${name}
      '';
    }).overrideAttrs (_: { passthru.providedSessions = [ name ]; });

  niriDmsSession = mkDmsSession { name = "niri-dms"; label = "Niri (DankMaterialShell)"; exec = "${niriLauncher}"; };
  labwcDmsSession = mkDmsSession { name = "labwc-dms"; label = "labwc (DankMaterialShell)"; exec = "${labwcLauncher}"; };
  mangoDmsSession = mkDmsSession { name = "mango-dms"; label = "mango (DankMaterialShell)"; exec = "${mangoLauncher}"; };
in
{
  options.desktop.dmsShell.enable =
    mkEnableOption "DankMaterialShell as selectable login sessions per WM (alongside Noctalia)";

  config = mkIf cfg.enable {
    programs.dms-shell = {
      enable = true;
      # The unit ships with the package (linked); niri's DMS session starts it on
      # demand. NOT wantedBy graphical-session.target (systemd.enable = false) so
      # it never auto-starts inside the Noctalia session.
      systemd.enable = false;
      # Keep Stylix/Gruvbox for the trial; set true to let DMS drive matugen
      # Material You theming from the wallpaper instead.
      enableDynamicTheming = false;
    };

    # Add a "(DankMaterialShell)" entry per enabled WM. The stock niri/labwc/mango
    # entries stay as the Noctalia sessions.
    services.displayManager.sessionPackages =
      [ niriDmsSession ]
      ++ optional config.desktop.labwc.enable labwcDmsSession
      ++ optional config.desktop.mangowm.enable mangoDmsSession;
  };
}
