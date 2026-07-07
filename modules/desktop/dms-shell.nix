{ config, lib, pkgs, ... }:
# DankMaterialShell (DMS) as a SECOND selectable niri login session, alongside
# Noctalia. The stock "Niri" session (from programs.niri) spawns whatever
# ${DESK_SHELL:-noctalia} resolves to — unset → Noctalia. This module adds a
# parallel "Niri (DankMaterialShell)" session whose launcher exports
# DESK_SHELL="dms run", so the same niri config starts DMS instead. Only one
# shell ever runs per session, so Noctalia and DMS never collide.
#
# See home/desktop/noctalia/default.nix (niri spawn-at-startup) for the
# ${DESK_SHELL:-noctalia} switch this pairs with.
let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.desktop.dmsShell;

  # Start a normal niri session, but select the DMS shell via the env var the
  # niri spawn reads. `dms run` launches quickshell with the DMS config.
  niriDmsLauncher = pkgs.writeShellScript "niri-dms-session" ''
    export DESK_SHELL="dms run"
    exec niri-session
  '';

  # services.displayManager.sessionPackages requires passthru.providedSessions
  # to match the .desktop basename ("niri-dms").
  dmsSession = (pkgs.writeTextFile {
    name = "niri-dms-wayland-session";
    destination = "/share/wayland-sessions/niri-dms.desktop";
    text = ''
      [Desktop Entry]
      Name=Niri (DankMaterialShell)
      Comment=niri with the DankMaterialShell desktop shell
      Exec=${niriDmsLauncher}
      Type=Application
      DesktopNames=niri
    '';
  }).overrideAttrs (_: { passthru.providedSessions = [ "niri-dms" ]; });
in
{
  options.desktop.dmsShell.enable =
    mkEnableOption "DankMaterialShell as a selectable niri login session (alongside Noctalia)";

  config = mkIf cfg.enable {
    programs.dms-shell = {
      enable = true;
      # Spawned per-session by niri (via DESK_SHELL), NOT globally — a global
      # systemd service would also start DMS inside the Noctalia session.
      systemd.enable = false;
      # Keep Stylix/Gruvbox for the trial; set true to let DMS drive matugen
      # Material You theming from the wallpaper instead.
      enableDynamicTheming = false;
    };

    # Add "Niri (DankMaterialShell)" to the greeter's session picker. The stock
    # "Niri" entry (from programs.niri) stays as the Noctalia session.
    services.displayManager.sessionPackages = [ dmsSession ];
  };
}
