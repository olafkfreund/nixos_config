# n8n — local workflow-automation runtime.
#
# Stands up the upstream `services.n8n` (which already runs hardened under
# DynamicUser + ProtectSystem=strict and loads any *_FILE env var via systemd
# credentials) behind a feature flag. The only NixOS-managed secret is the n8n
# encryption key (agenix); all workflow/service API keys (Overseerr, Tautulli,
# Home Assistant, …) live as n8n *credentials*, encrypted by that key inside
# n8n's own store and entered at runtime in the n8n UI.
#
# Network: binds 127.0.0.1 only (firewall untouched). On p510 every consumer
# (Tautulli, Overseerr, Lidarr, ollama) is co-located, so loopback suffices.
#
# Used by the "just-finished" media-recommendation workflow.
# See docs/plans/2026-05-26-plex-llm-recommendations-design.md.
{ config
, lib
, ...
}:
let
  cfg = config.features.n8n;
in
{
  options.features.n8n = {
    enable = lib.mkEnableOption "n8n workflow-automation runtime (localhost, agenix-keyed)";

    port = lib.mkOption {
      type = lib.types.port;
      default = 5678;
      description = "Loopback HTTP port n8n listens on. Never exposed to the network (no firewall opening).";
    };

    publicUrl = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "https://n8n.example.com";
      description = ''
        External base URL when fronting n8n with a reverse proxy (cloudflared,
        Tailscale Serve, Caddy, …). When set, n8n is told its public hostname
        and protocol so webhook URLs, OAuth callbacks, and Secure cookies all
        reference the proxy address instead of localhost. The listen address
        stays loopback — wire the proxy separately.

        Leave null for loopback-only operation (the original module behavior).
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # Only the encryption key is a NixOS secret; service API keys are n8n
    # credentials encrypted by this key at runtime.
    age.secrets."n8n-encryption-key" = {
      file = ../../secrets/n8n-encryption-key.age;
      mode = "0400";
    };

    services.n8n = {
      enable = true;
      # openFirewall stays false (default): loopback-only access.
      environment = {
        N8N_PORT = cfg.port;
        # Bind loopback only; co-located clients on this host reach it directly.
        N8N_LISTEN_ADDRESS = "127.0.0.1";
        # Runtime-loaded via systemd credential (DynamicUser-safe). n8n reads the
        # _FILE variant natively; the upstream module rewrites it to the cred path.
        N8N_ENCRYPTION_KEY_FILE = config.age.secrets."n8n-encryption-key".path;
        # Skip the first-run personalization survey on a headless instance.
        N8N_PERSONALIZATION_ENABLED = false;
        # GENERIC_TIMEZONE defaults to config.time.timeZone; diagnostics and
        # version-notifications already default to false upstream.
      } // lib.optionalAttrs (cfg.publicUrl != null) (
        let
          # Parse "scheme://host[:port][/path]" into the pieces n8n wants.
          # cfg.publicUrl is the externally-visible base URL.
          parts = builtins.match "(https?)://([^/:]+)(:[0-9]+)?(/.*)?" cfg.publicUrl;
          scheme = builtins.elemAt parts 0;
          host = builtins.elemAt parts 1;
        in
        {
          N8N_HOST = host;
          N8N_PROTOCOL = scheme;
          # Trailing slash matters: n8n appends webhook paths to this verbatim.
          WEBHOOK_URL = "${cfg.publicUrl}/";
          # One reverse proxy in front (cloudflared / Tailscale Serve / nginx).
          N8N_PROXY_HOPS = 1;
        }
      );
    };

    assertions = lib.optional (cfg.publicUrl != null) {
      assertion = builtins.match "https?://[^/:]+(:[0-9]+)?(/.*)?" cfg.publicUrl != null;
      message = "features.n8n.publicUrl must be of the form http(s)://host[:port][/path]; got: ${cfg.publicUrl}";
    };
  };
}
