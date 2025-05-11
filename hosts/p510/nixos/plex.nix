{
  pkgs-unstable,
  config,
  lib,
  ...
}: {
  services = {
    plex = {
      enable = true;
      user = "olafkfreund";
      accelerationDevices = ["*"];
      dataDir = "/mnt/media/plex";
      package = pkgs-unstable.plex;
      extraPlugins = [];
    };

    nzbget = {
      enable = true;
      user = "olafkfreund";
      package = pkgs-unstable.nzbget;
    };

    radarr = {
      enable = true;
      user = "olafkfreund";
      dataDir = "/mnt/media/radarr";
      package = pkgs-unstable.radarr;
    };

    sonarr = {
      enable = true;
      user = "olafkfreund";
      dataDir = "/mnt/media/sonarr";
      package = pkgs-unstable.sonarr;
    };

    tautulli = {
      enable = true;
      user = "olafkfreund";
      dataDir = "/mnt/media/tautulli";
      package = pkgs-unstable.tautulli;
    };

    lidarr = {
      enable = true;
      user = "olafkfreund";
      dataDir = "/mnt/media/lidarr";
      package = pkgs-unstable.lidarr;
    };

    transmission = {
      enable = true;
      user = "olafkfreund";
      # group = "users";
      home = "/mnt/media/transmission";
      package = pkgs-unstable.transmission_4;
      downloadDirPermissions = "0775";
      settings = {
        trash-original-torrent-files = true;
        rpc-bind-address = "0.0.0.0";
        rpc-whitelist = "127.0.0.1,192.168.1.97";
        watch-dir-enabled = true;
        watch-dir = "${config.services.transmission.home}/watchdir";
        download-dir = "/mnt/media/Media/Audiobooks/Downloads";
        incomplete-dir-enabled = true;
        incomplete-dir = "/mnt/media/Media/Audiobooks/incomplete";
      };
    };

    prowlarr = {
      enable = true;
      user = "olafkfreund";
      dataDir = "/mnt/media/prowlarr";
      package = pkgs-unstable.prowlarr;
    };

    nfs.server = {
      enable = true;
      exports = ''
        /mnt/media         *(rw,fsid=0,no_subtree_check)
      '';
    };
  };

  virtualisation.oci-containers = {
    backend = "podman"; # You can use "docker" if preferred
    containers = {
      overseerr = {
        image = "sctx/overseerr";
        environment = {
          LOG_LEVEL = "debug";
          TZ = "Europe/London"; # Adjusted timezone to match your likely location
          PORT = "5055";
        };
        ports = ["5055:5055"];
        volumes = [
          "/mnt/media/overseerr:/app/config"
        ];
        extraOptions = [
          "--name=overseerr"
          "--restart=unless-stopped"
        ];
      };
    };
  };

  systemd.tmpfiles.rules = [
    "d /mnt/media/overseerr 0755 olafkfreund users -"
  ];

  networking.firewall.allowedTCPPorts = [5055];
}
