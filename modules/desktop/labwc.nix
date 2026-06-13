{ config, lib, pkgs, ... }:
# labwc — stacking (Openbox-like) Wayland compositor, exposed as a selectable
# login session. nixpkgs' labwc ships no wayland-sessions/*.desktop, so we
# generate one and register it via services.displayManager.sessionPackages
# (same mechanism the COSMIC greeter wiring on razer relies on). A usable
# default config + the Noctalia shell land in a later phase.
let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.desktop.labwc;

  # services.displayManager.sessionPackages requires the package to declare
  # passthru.providedSessions matching the .desktop basename ("labwc").
  labwcSession = (pkgs.writeTextFile {
    name = "labwc-wayland-session";
    destination = "/share/wayland-sessions/labwc.desktop";
    text = ''
      [Desktop Entry]
      Name=labwc
      Comment=Openbox-like stacking Wayland compositor
      Exec=labwc
      Type=Application
    '';
  }).overrideAttrs (_: { passthru.providedSessions = [ "labwc" ]; });
in
{
  options.desktop.labwc.enable =
    mkEnableOption "labwc stacking Wayland compositor (selectable login session)";

  config = mkIf cfg.enable {
    environment.systemPackages = [ pkgs.labwc ];

    # Make greetd/GDM list "labwc" as a session.
    services.displayManager.sessionPackages = [ labwcSession ];
  };
}
