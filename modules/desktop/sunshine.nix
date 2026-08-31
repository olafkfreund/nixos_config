{ config
, lib
, ...
}:
# Sunshine: stream this machine's Wayland session to a Moonlight client.
#
# This exists because p510 gained a monitor and an Omarchy session, and the
# remote path it used to have does not reach that session. gnome-remote-desktop
# serves GNOME -- it is a GNOME Shell component using GNOME's own screencast
# pipeline -- so with Hyprland as the session there is nothing on the other end
# of RDP. Sunshine captures the compositor's output directly instead, which is
# compositor-agnostic, and encodes on the GPU.
#
# Two things about this service are unusual enough to state:
#
#   It is a systemd USER service, not a system one. Upstream's module puts it in
#   the user session because it has to talk to the running compositor. So it
#   comes up when a graphical session does and not a moment sooner: on a host
#   that reboots unattended, remote access therefore depends on that session
#   existing without a human at the keyboard. That is why p510 keeps autologin
#   on while p620 and razer do not.
#
#   The hardening rules in CLAUDE.md do not apply and cannot. DynamicUser,
#   ProtectHome and ProtectSystem = "strict" all assume a service that needs
#   nothing of the user's session; this one needs the user's Wayland socket,
#   their GPU device nodes and their input devices. Sandboxing it to the point
#   the rules ask for is the same as switching it off, so the deliberate
#   exception is recorded here rather than silently taken.
let
  inherit (lib) mkIf mkEnableOption mkOption types;
  cfg = config.features.sunshine;
in
{
  options.features.sunshine = {
    enable = mkEnableOption "Sunshine desktop streaming host (for Moonlight clients)";

    openFirewall = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Open the ports Sunshine needs. It is not one port: 47984/47989/48010
        TCP and 47998-48000/48002/48010 UDP, which is why this defers to
        upstream's own option rather than listing them here and drifting.

        Sunshine's web UI (47990) is HTTPS with a self-signed certificate and
        its own login, set on first visit. Leave this on only on a network
        where that is an acceptable front door.
      '';
    };

    capSysAdmin = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Grant the Sunshine binary CAP_SYS_ADMIN, which is what KMS capture
        needs on Wayland. Without it Sunshine falls back to a portal-based
        path that Hyprland can serve but which re-prompts, or fails outright
        with "Couldn't find any working capture method".

        This is a real privilege on a real binary, and it is the reason this
        option is spelled out instead of hardcoded: a host that would rather
        take the portal route can turn it off in one line.
      '';
    };

    webOrigins = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [ "https://192.168.1.75:47990" "https://myhost:47990" ];
      description = ''
        Origins allowed to use Sunshine's web UI, as scheme://host:port.

        Sunshine trusts only localhost, 127.0.0.1 and [::1] by default and
        refuses every POST from anywhere else with

          CSRF Protection Error
          The request was blocked by CSRF protection.

        That includes the request that creates the first username and
        password, so reaching the UI across the LAN is not merely restricted
        -- the page loads and nothing on it can be submitted. Every host that
        is administered from another machine needs its own address here.

        Include the port: the browser sends it in the Origin header, so
        "https://host" does not match "https://host:47990".

        Setting this has a side effect worth knowing, and it comes from
        upstream's module rather than from here: Sunshine is only handed a
        config file when some setting differs from the default, and that file
        lives in the Nix store, read-only. So as soon as this list is
        non-empty the web UI's Configuration tab can no longer save --
        settings belong in this repository from then on. Credentials and
        client pairings are not affected; those live in
        ~/.config/sunshine/sunshine_state.json, which stays writable.
      '';
    };
  };


  config = mkIf cfg.enable {
    services.sunshine = {
      enable = true;
      inherit (cfg) openFirewall capSysAdmin;

      # Comma-separated, no spaces, as the option's own parser expects; an
      # entry it cannot read is dropped with "Invalid 'csrf_allowed_origins'
      # entry rejected" and the origin stays blocked.
      settings = lib.mkIf (cfg.webOrigins != [ ]) {
        csrf_allowed_origins = lib.concatStringsSep "," cfg.webOrigins;
      };

      # Start with the session rather than waiting for someone to run it.
      # Pointless without autologin on a headless-reboot host; harmless with.
      autoStart = true;
    };
  };
}
