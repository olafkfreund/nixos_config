# Cloudflare Tunnel — public ingress for p510 services from behind Starlink CGNAT.
#
# Outbound-only tunnel from p510 to Cloudflare's edge. No port forwards, no
# public IP needed. Each route maps a hostname under `freundcloud.org.uk`
# (Cloudflare-managed zone) to a local URL on p510.
#
# Thin feature-flag wrapper over upstream `services.cloudflared`. The
# credentials.json from `cloudflared tunnel create` lives in agenix
# (cloudflared-credentials.age); the cert.pem from `cloudflared login`
# lives in agenix too (cloudflared-cert.age). Routes are declarative —
# add a new entry to `cfg.ingress`, deploy, optionally run
# `cloudflared tunnel route dns <tunnel> <hostname>` once to add the
# Cloudflare DNS CNAME (or do it via dashboard).
#
# One-time bootstrap (run on a workstation with browser access — NOT p510):
#   1. nix-shell -p cloudflared
#   2. cloudflared login          # → opens browser; saves ~/.cloudflared/cert.pem
#   3. cloudflared tunnel create p510-home
#      # → prints tunnel UUID, saves ~/.cloudflared/<UUID>.json
#   4. Copy cert.pem + <UUID>.json into agenix via manage-secrets.sh
#      (one secret each: cloudflared-cert, cloudflared-credentials)
#   5. Set features.cloudflared.tunnelId to the UUID and deploy
#
# Adding a Cloudflare DNS record for a hostname (one-time per hostname):
#   cloudflared tunnel route dns p510-home argocd.freundcloud.org.uk
#   # or click-route in the Cloudflare Zero Trust dashboard
#
# References:
#   https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/
#   https://nixos.wiki/wiki/Cloudflare_tunnel
{ config
, lib
, ...
}:
let
  cfg = config.features.cloudflared;
in
{
  options.features.cloudflared = {
    enable = lib.mkEnableOption "Cloudflare Tunnel client — public ingress from behind Starlink CGNAT";

    tunnelId = lib.mkOption {
      type = lib.types.str;
      description = ''
        Tunnel UUID issued by `cloudflared tunnel create`. The credentials
        file in agenix MUST match this UUID — they are paired.
      '';
      example = "deadbeef-1234-5678-9abc-def012345678";
    };

    ingress = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      example = lib.literalExpression ''
        {
          "argocd.freundcloud.org.uk" = "http://localhost:80";
          "backstage.freundcloud.org.uk" = "http://localhost:7007";
        }
      '';
      description = ''
        Map of public hostnames to local service URLs that cloudflared will
        proxy. Each hostname MUST also have a Cloudflare DNS CNAME pointing
        at <tunnelId>.cfargotunnel.com — created once via:

          cloudflared tunnel route dns p510-home <hostname>

        or via the Cloudflare Zero Trust dashboard.

        Default fallback (`services.cloudflared.tunnels.<id>.default`) is
        set below to `http_status:404` so any miss returns a clean 404
        rather than leaking that the tunnel exists.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # Both files come from `cloudflared login` / `cloudflared tunnel create`
    # on a one-time workstation bootstrap (see header comment). Owner is
    # root because cloudflared's systemd unit uses LoadCredential to project
    # them into the unit's runtime credential directory — DynamicUser
    # doesn't need to own them on disk.
    age.secrets = {
      cloudflared-cert = {
        file = ../../secrets/cloudflared-cert.age;
        mode = "0400";
      };
      cloudflared-credentials = {
        file = ../../secrets/cloudflared-credentials.age;
        mode = "0400";
      };
    };

    services.cloudflared = {
      enable = true;
      certificateFile = config.age.secrets.cloudflared-cert.path;
      tunnels.${cfg.tunnelId} = {
        credentialsFile = config.age.secrets.cloudflared-credentials.path;
        # No matching hostname → quiet 404. Don't leak that the tunnel is up.
        default = "http_status:404";
        ingress = cfg.ingress;
      };
    };
  };
}
