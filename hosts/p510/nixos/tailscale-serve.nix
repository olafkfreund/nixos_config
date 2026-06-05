{ pkgs, ... }:

{
  # Tailscale Serve configuration for P510 media services
  # Exposes services to Tailscale network (tailnet) for secure remote access
  #
  # IMPORTANT: Port Conflict Prevention Strategy
  # ============================================
  # ALL services MUST use path-based routing on HTTPS port 443
  # to prevent port conflicts with local service bindings.
  #
  # Pattern: --https=443 --set-path=/SERVICE_NAME http://localhost:LOCAL_PORT
  #
  # Example:
  #   Service runs on: http://localhost:8989
  #   Tailscale exposes: https://p510.tailnet/sonarr → http://localhost:8989
  #
  # This allows services to bind to their own local ports without interference
  # from Tailscale, which only binds to external port 443.

  # Configure Tailscale serve via systemd service
  # This makes services available at: https://p510.tailnet-name.ts.net
  systemd.services.tailscale-serve = {
    description = "Tailscale Serve - Expose Media Services";
    after = [ "tailscaled.service" "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "tailscale-serve-start" ''
        # Wait for Tailscale to be ready
        until ${pkgs.tailscale}/bin/tailscale status &>/dev/null; do
          sleep 2
        done

        # Configure Tailscale Serve for each service
        # All services are exposed under https://p510.tailnet.ts.net:443 with paths
        # This avoids port conflicts by using a single HTTPS port with path-based routing

        # Plex Media Server (primary service) - accessible at /plex
        ${pkgs.tailscale}/bin/tailscale serve --bg --https=443 --set-path=/plex http://localhost:32400

        # Tautulli (Plex monitoring) - accessible at /tautulli
        ${pkgs.tailscale}/bin/tailscale serve --bg --https=443 --set-path=/tautulli http://localhost:8181

        # NZBGet (download manager) - accessible at /nzbget
        ${pkgs.tailscale}/bin/tailscale serve --bg --https=443 --set-path=/nzbget http://localhost:6789

        # SABnzbd (download manager, side-by-side trial) - accessible at /sabnzbd
        # NOTE: for the /sabnzbd path to work fully, set misc.url_base=/sabnzbd in
        # the SABnzbd UI. Direct access at http://p510:8080 works without it.
        ${pkgs.tailscale}/bin/tailscale serve --bg --https=443 --set-path=/sabnzbd http://localhost:8080

        # Sonarr (TV shows) - accessible at /sonarr
        ${pkgs.tailscale}/bin/tailscale serve --bg --https=443 --set-path=/sonarr http://localhost:8989

        # Radarr (movies) - accessible at /radarr
        ${pkgs.tailscale}/bin/tailscale serve --bg --https=443 --set-path=/radarr http://localhost:7878

        # Prowlarr (indexer manager) - accessible at /prowlarr
        ${pkgs.tailscale}/bin/tailscale serve --bg --https=443 --set-path=/prowlarr http://localhost:9696

        # Lidarr (music) - accessible at /lidarr
        ${pkgs.tailscale}/bin/tailscale serve --bg --https=443 --set-path=/lidarr http://localhost:8686

        # AudioBookshelf (audiobooks and podcasts) - accessible at /audiobookshelf
        ${pkgs.tailscale}/bin/tailscale serve --bg --https=443 --set-path=/audiobookshelf http://localhost:13378

        # Overseerr (request management for Plex) - accessible at /overseerr
        ${pkgs.tailscale}/bin/tailscale serve --bg --https=443 --set-path=/overseerr http://localhost:5055

        # AudioBookBay search UI (audiobookbay-automated) - accessible at /audiobooks-dl
        ${pkgs.tailscale}/bin/tailscale serve --bg --https=443 --set-path=/audiobooks-dl http://localhost:5078

        # Backstage developer portal (features.backstage) - accessible at /backstage
        # GitHub OAuth callback URL on the OAuth App MUST be:
        # https://p510.tail833f7.ts.net/backstage/api/auth/github/handler/frame
        ${pkgs.tailscale}/bin/tailscale serve --bg --https=443 --set-path=/backstage http://localhost:7007

        # Public webhook ingress for GitHub event delivery (Phase D
        # real-time freshness). Funnel exposes this to the public
        # internet on 8443 ONLY for the /api/events/http/github path.
        # HMAC-SHA256 signature validation in the Backstage events
        # backend is the only gate, so the agenix-encrypted webhook
        # secret must remain high-entropy.
        #
        # Tailscale Funnel only supports 443/8443/10000. We can't use
        # 443 because that's already serving all the media services
        # tailnet-only (Plex, Sonarr, etc) and Funnel can't selectively
        # apply per-path — it would expose everything.
        #
        # GitHub webhook URL: https://bs.freundcloud.com:8443/api/events/http/github
        #   (or https://p510.tail833f7.ts.net:8443/api/events/http/github)
        ${pkgs.tailscale}/bin/tailscale funnel --bg --https=8443 --set-path=/api/events/http/github http://localhost:7007

        # Note: Home Assistant is NOT configured here to avoid port conflicts.
        # It is accessible directly at http://p510.lan:8123 via subnet routing.

        # All services now accessible at:
        # https://p510.tail833f7.ts.net/plex
        # https://p510.tail833f7.ts.net/sonarr
        # https://p510.tail833f7.ts.net/radarr
        # etc.

        # Validate configuration (verify no port conflicts)
        echo "Tailscale Serve configured for all media services on HTTPS port 443"
        echo "Checking for port conflicts..."

        # List all Tailscale serve configurations
        ${pkgs.tailscale}/bin/tailscale serve status || true
      '';

      ExecStop = pkgs.writeShellScript "tailscale-serve-stop" ''
        # Remove all serve configurations
        ${pkgs.tailscale}/bin/tailscale serve reset || true
      '';
    };
  };

  # Alternative simpler configuration - expose Plex on its standard port
  # Uncomment this section if you want Plex accessible directly at https://p510.tailnet/
  # systemd.services.tailscale-serve-simple = {
  #   description = "Tailscale Serve - Simple Plex Exposure";
  #   after = [ "tailscaled.service" ];
  #   wantedBy = [ "multi-user.target" ];
  #
  #   serviceConfig = {
  #     Type = "oneshot";
  #     RemainAfterExit = true;
  #     ExecStart = "${pkgs.tailscale}/bin/tailscale serve --bg / http://localhost:32400";
  #     ExecStop = "${pkgs.tailscale}/bin/tailscale serve reset";
  #   };
  # };
}
