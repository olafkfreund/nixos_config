{ pkgs-unstable
, config
, ...
}: {
  services = {
    # Overseerr - Request management and media discovery for Plex
    overseerr = {
      enable = true;
      port = 5055;
      openFirewall = true;
      package = pkgs-unstable.overseerr;
    };
    plex = {
      enable = true;
      user = "olafkfreund";
      accelerationDevices = [ "*" ];
      dataDir = "/mnt/media/plex";
      package = pkgs-unstable.plex;
      extraPlugins = [ ];
    };

    nzbget = {
      enable = true;
      user = "olafkfreund";
      package = pkgs-unstable.nzbget;
      settings = {
        MainDir = "/mnt/media/nzbget";
        DestDir = "/mnt/media/Media/Downloads";
        InterDir = "/mnt/media/nzbget/intermediate";
        QueueDir = "/mnt/media/nzbget/queue";
        TempDir = "/mnt/media/nzbget/tmp";
        ControlIP = "0.0.0.0";
        ControlPort = 6789;
        ControlUsername = "nzbget";
        ControlPassword = "Xs4monly4e!!";
        # API access for monitoring
        AuthorizedIP = "127.0.0.1,192.168.1.*";
      };
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
      port = 8181;
    };

    lidarr = {
      enable = true;
      user = "olafkfreund";
      dataDir = "/mnt/media/lidarr";
      package = pkgs-unstable.lidarr;
    };

    audiobookshelf = {
      enable = true;
      user = "olafkfreund";
      group = "users";
      port = 13378;
      host = "0.0.0.0";
      dataDir = "audiobookshelf"; # Relative path under /var/lib
      package = pkgs-unstable.audiobookshelf;
    };

    transmission = {
      enable = true;
      user = "olafkfreund";
      home = "/mnt/media/transmission";
      package = pkgs-unstable.transmission_4;
      downloadDirPermissions = "0775";
      settings = {
        trash-original-torrent-files = true;
        rpc-bind-address = "0.0.0.0";
        rpc-whitelist = "127.0.0.1,192.168.1.*";
        watch-dir-enabled = true;
        watch-dir = "${config.services.transmission.home}/watchdir";
        download-dir = "/mnt/media/Media/Audiobooks/Downloads";
        incomplete-dir-enabled = true;
        incomplete-dir = "/mnt/media/Media/Audiobooks/incomplete";
      };
    };

    prowlarr = {
      enable = true;
      dataDir = "/mnt/media/prowlarr";
      package = pkgs-unstable.prowlarr;
    };

    # jackett = {
    #   enable = true;
    #   user = "olafkfreund";
    #   dataDir = "/mnt/media/jackett";
    #   package = pkgs-unstable.jackett;
    # };

    nfs.server = {
      enable = true;
      # Performance-optimized NFS configuration
      nproc = 16; # Increase number of NFS server processes
      lockdPort = 4001; # Fixed port for firewalls
      mountdPort = 4002; # Fixed mount daemon port
      statdPort = 4000; # Fixed status daemon port
      exports = ''
        /mnt/media         *(rw,fsid=0,no_subtree_check,sync,wdelay,insecure,root_squash,all_squash,anonuid=1000,anongid=100)
      '';
    };

    nfs.settings = {
      # Performance optimizations
      nfsd = {
        threads = 16;
        host = "*";
        port = 2049;
        vers3 = "y";
        vers4 = "y";
        "vers4.0" = "y";
        "vers4.1" = "y";
        "vers4.2" = "y";
      };

      exportfs = {
        debug = 0;
      };

      gssd = {
        use-memcache = 1;
      };
    };
  };

  systemd.tmpfiles.rules = [
    # "d /mnt/media/jackett 0755 olafkfreund users -"  # Removed - no longer in use
    "d /mnt/media/prowlarr 0755 olafkfreund users -"
    "d /mnt/media/nzbget 0755 olafkfreund users -"
    "d /mnt/media/nzbget/intermediate 0755 olafkfreund users -"
    "d /mnt/media/nzbget/queue 0755 olafkfreund users -"
    "d /mnt/media/nzbget/tmp 0755 olafkfreund users -"
    "d /mnt/media/Media/Downloads 0755 olafkfreund users -"
    # AudioBookshelf directories
    "d /mnt/media/Media/Audiobooks 0755 olafkfreund users -"
    "d /mnt/media/Media/Podcasts 0755 olafkfreund users -"
    "d /mnt/media/audiobookshelf 0755 olafkfreund users -"
  ];

  # Ensure media services start before Tailscale Serve to prevent port conflicts
  systemd.services.tailscale-serve = {
    after = [ "overseerr.service" "audiobookshelf.service" ];
    wants = [ "overseerr.service" "audiobookshelf.service" ];
  };

  # Note: Firewall ports are now comprehensively configured in configuration.nix
  # This includes all media services, Plex discovery, NFS, and monitoring exporters
  # with Tailscale trustedInterfaces configuration
}
