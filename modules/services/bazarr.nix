# Bazarr — subtitle manager for Sonarr/Radarr/Lidarr on p510.
#
# Thin wrapper over nixpkgs's services.bazarr. We add a feature flag for
# consistency with the other media services, plus narrow the firewall
# opening to tailscale0 (and optionally a named LAN interface) instead
# of using `openFirewall = true` which would expose the port globally.
#
# Storage: nixpkgs default `/var/lib/bazarr` (small config + SQLite db).
# Subtitle .srt files are written *next to* the video files in
# `/mnt/media`, not into Bazarr's own data dir — no extra config needed.
#
# First-deploy UX (one-time, in the Bazarr web UI at http://p510:6767):
#   1. Settings → Sonarr → add: localhost:8989 + SONARR_API_KEY
#   2. Settings → Radarr → add: localhost:7878 + RADARR_API_KEY
#      (API keys can be found in arr-suite-mcp-env.age — pasted via UI;
#       Bazarr stores them in its own DB after that)
#   3. Settings → Languages → enable Norwegian Bokmål (nb) + English (en)
#   4. Settings → Languages → Default Profile:
#        a. Norwegian Bokmål  (forced=False)
#        b. English           (forced=False)
#   5. Settings → Providers → enable OpenSubtitles.com (anonymous works;
#      authenticate later for higher daily quota)
#   6. Tick "use embedded subs" if present (saves a download when the
#      release already has subs muxed in)
#
# Phase 2 candidate: declarative initial-config via Bazarr's REST API at
# first deploy, similar to the *arr webhook wiring for media-bot.
{ config
, lib
, ...
}:
let
  cfg = config.features.bazarr;
  port = 6767; # nixpkgs default
in
{
  options.features.bazarr = {
    enable = lib.mkEnableOption "Bazarr subtitle manager";

    listenLanInterface = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "eno1";
      description = ''
        LAN interface to also open the Bazarr port on, in addition to
        tailscale0. null exposes the service only via Tailscale (the
        recommended setting; Bazarr's UI is fine over the tailnet).
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    services.bazarr = {
      enable = true;
      # We open the firewall ourselves below (tailnet + optional LAN);
      # nixpkgs's `openFirewall = true` would open it on every interface.
      openFirewall = false;
      # Run as olafkfreund:users — same as services.sonarr / services.radarr
      # on this host. The TV/Movies dirs are owned by olafkfreund:users with
      # 755 perms; Bazarr writes .srt files next to videos and would hit
      # PermissionError(13) under the nixpkgs-default `bazarr` system user.
      user = "olafkfreund";
      group = "users";
    };

    # After flipping bazarr's runtime user we need its state dir (default
    # /var/lib/bazarr — SQLite DB, cache, log) re-owned. Idempotent oneshot
    # so future deploys are no-ops.
    systemd.services.bazarr-chown = {
      description = "Reclaim ownership of /var/lib/bazarr after user switch";
      wantedBy = [ "multi-user.target" ];
      before = [ "bazarr.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        if [ -d /var/lib/bazarr ]; then
          chown -R olafkfreund:users /var/lib/bazarr
        fi
      '';
    };

    networking.firewall.interfaces = lib.mkMerge [
      { "tailscale0".allowedTCPPorts = [ port ]; }
      (lib.mkIf (cfg.listenLanInterface != null) {
        "${cfg.listenLanInterface}".allowedTCPPorts = [ port ];
      })
    ];
  };
}
