{ pkgs, ... }:

{
  # Tailscale Serve configuration for P510 media services
  # Exposes services to Tailscale network (tailnet) for secure remote access

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
        # These services will be accessible via HTTPS on the Tailscale network

        # Plex Media Server (primary service)
        ${pkgs.tailscale}/bin/tailscale serve --bg --https=32400 --set-path=/plex http://localhost:32400

        # Tautulli (Plex monitoring)
        ${pkgs.tailscale}/bin/tailscale serve --bg --https=8181 --set-path=/tautulli http://localhost:8181

        # NZBGet (download manager)
        ${pkgs.tailscale}/bin/tailscale serve --bg --https=6789 --set-path=/nzbget http://localhost:6789

        # Sonarr (TV shows)
        ${pkgs.tailscale}/bin/tailscale serve --bg --https=8989 --set-path=/sonarr http://localhost:8989

        # Radarr (movies)
        ${pkgs.tailscale}/bin/tailscale serve --bg --https=7878 --set-path=/radarr http://localhost:7878

        # Prowlarr (indexer manager)
        ${pkgs.tailscale}/bin/tailscale serve --bg --https=9696 --set-path=/prowlarr http://localhost:9696

        # Lidarr (music)
        ${pkgs.tailscale}/bin/tailscale serve --bg --https=8686 --set-path=/lidarr http://localhost:8686

        # AudioBookshelf (audiobooks and podcasts)
        ${pkgs.tailscale}/bin/tailscale serve --bg --https=13378 --set-path=/audiobookshelf http://localhost:13378

        # Overseerr (request management for Plex)
        ${pkgs.tailscale}/bin/tailscale serve --bg --https=5055 --set-path=/overseerr http://localhost:5055

        # Jackett removed - no longer in use
        # ${pkgs.tailscale}/bin/tailscale serve --bg --https=9117 --set-path=/jackett http://localhost:9117

        echo "Tailscale Serve configured for all media services"
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
