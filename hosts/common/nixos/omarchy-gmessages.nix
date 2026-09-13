# Google Messages in the Omarchy bar (MarcFord/gmessages-omarchy-plugin).
#
# A user service, not a DynamicUser one: pairing reads Chrome's cookie DB from
# ~/.config/google-chrome and its key from the login keyring, so it must run as
# the desktop user. Upstream's hardening is kept as-is.
#
# One-time per machine, since nixarchy installs plugins but does not enable them:
#   omarchy plugin enable marcford.gmessages
# Then open https://messages.google.com/web in Chrome once (it issues the OSID
# cookie pairing needs) and press "Pair with Google" in the bar panel.
{ pkgs, ... }:
let
  gmessages = pkgs.customPkgs.gmessages-omarchy;
in
{
  home-manager.users.olafkfreund = {
    programs.nixarchy.plugins."marcford.gmessages".src = gmessages.plugin;

    # The panel shells out to these itself (voice, webcam, QR fallback).
    home.packages = [ gmessages pkgs.ffmpeg pkgs.qrencode ];

    # ReadWritePaths= is resolved before ExecStart, so the dir must pre-exist.
    systemd.user.tmpfiles.rules = [ "d %h/.local/share/gmessages-omarchy 0700 - - -" ];

    systemd.user.services.gmessagesd = {
      Unit = {
        Description = "Google Messages daemon for the Omarchy bar plugin";
        After = [ "graphical-session.target" ];
      };
      Service = {
        ExecStart = "${gmessages}/bin/gmessagesd";
        Restart = "on-failure";
        RestartSec = "5s";
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = "read-only";
        RuntimeDirectory = "gmessages-omarchy";
        RuntimeDirectoryMode = "0700";
        CacheDirectory = "gmessages-omarchy";
        CacheDirectoryMode = "0700";
        ReadWritePaths = [ "%h/.local/share/gmessages-omarchy" ];
        NoNewPrivileges = true;
        ProtectKernelTunables = true;
        ProtectControlGroups = true;
        RestrictNamespaces = true;
        RestrictSUIDSGID = true;
        MemoryDenyWriteExecute = true;
      };
      Install.WantedBy = [ "default.target" ];
    };
  };
}
