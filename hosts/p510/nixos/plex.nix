{ config
, pkgs-unstable
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
        MainDir = "/mnt/media/downloads/usenet";
        DestDir = "/mnt/media/downloads/usenet/complete";
        InterDir = "/mnt/media/downloads/usenet/incomplete";
        QueueDir = "/mnt/media/downloads/usenet/queue";
        TempDir = "/mnt/media/downloads/usenet/tmp";
        ControlIP = "0.0.0.0";
        ControlPort = 6789;
        ControlUsername = "nzbget";
        ControlPassword = "Xs4monly4e!!";
        # API access for monitoring
        AuthorizedIP = "127.0.0.1,192.168.1.*";
      };
    };

    # SABnzbd — running side-by-side with NZBGet for evaluation before
    # cutover. Mirrors the NZBGet setup (Easynews server, same categories)
    # but uses fully isolated download dirs under /mnt/media/downloads/sabnzbd
    # so it can't collide with NZBGet's in-flight downloads. NZBGet remains
    # the active download client for Sonarr/Radarr; add SABnzbd as a second
    # client in the *arr UIs when ready to test.
    #
    # Non-secret config is declarative below; the Easynews username/password
    # come from agenix via secretFiles (never in the Nix store). allowConfigWrite
    # is on for the trial so settings can also be tweaked in the SABnzbd UI.
    # Access during the trial: http://p510:8080 (LAN + tailnet, firewall is off).
    sabnzbd = {
      enable = true;
      user = "olafkfreund";
      group = "users";
      package = pkgs-unstable.sabnzbd;
      # P510 is on stateVersion 25.11, where configFile defaults to the legacy
      # /var/lib path — which makes the module IGNORE `settings`. Force null so
      # our declarative settings + secretFiles are actually used.
      configFile = null;
      allowConfigWrite = true;
      secretFiles = [ config.age.secrets."sabnzbd-secrets".path ];
      settings = {
        misc = {
          host = "0.0.0.0";
          port = 8080;
          download_dir = "/mnt/media/downloads/sabnzbd/incomplete";
          complete_dir = "/mnt/media/downloads/sabnzbd/complete";
          dirscan_dir = "/mnt/media/downloads/sabnzbd/watch";
          permissions = "775";
          # Allow access via LAN + tailnet hostnames (SABnzbd blocks unknown Host headers).
          host_whitelist = "p510,p510.lan,p510.local,p510.home.freundcloud.com,p510.tail833f7.ts.net,localhost";
        };
        # Easynews — mirrors NZBGet Server1 (plaintext, port 119, 20 conns).
        # username/password are supplied by secretFiles (agenix); they are
        # intentionally absent from the typed schema here.
        servers.Easynews = {
          name = "Easynews";
          displayname = "Easynews";
          host = "news.eu.easynews.com";
          port = 119;
          ssl = false;
          connections = 20;
          enable = true;
        };
        categories = {
          Movies = { name = "Movies"; order = 0; pp = 3; script = "None"; dir = "Movies"; priority = -100; };
          TV = { name = "TV"; order = 1; pp = 3; script = "None"; dir = "TV"; priority = -100; };
          Music = { name = "Music"; order = 2; pp = 3; script = "None"; dir = "Music"; priority = -100; };
          Prowlarr = { name = "Prowlarr"; order = 3; pp = 3; script = "None"; dir = "Prowlarr"; priority = -100; };
        };
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
      home = "/mnt/media/downloads/torrents";
      package = pkgs-unstable.transmission_4;
      downloadDirPermissions = "0775";
      settings = {
        trash-original-torrent-files = true;
        rpc-bind-address = "0.0.0.0";
        rpc-whitelist = "127.0.0.1,192.168.1.*,100.*.*.*";
        rpc-whitelist-enabled = true;
        rpc-authentication-required = false;
        watch-dir-enabled = true;
        watch-dir = "/mnt/media/downloads/torrents/watch";
        download-dir = "/mnt/media/downloads/torrents/complete";
        incomplete-dir-enabled = true;
        incomplete-dir = "/mnt/media/downloads/torrents/incomplete";
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
    "d /mnt/media/prowlarr 0755 olafkfreund users -"
    "d /mnt/media/downloads 0775 olafkfreund users -"
    "d /mnt/media/downloads/torrents 0775 olafkfreund users -"
    "d /mnt/media/downloads/torrents/complete 0775 olafkfreund users -"
    "d /mnt/media/downloads/torrents/incomplete 0775 olafkfreund users -"
    "d /mnt/media/downloads/torrents/watch 0775 olafkfreund users -"
    "d /mnt/media/downloads/usenet 0775 olafkfreund users -"
    "d /mnt/media/downloads/usenet/complete 0775 olafkfreund users -"
    "d /mnt/media/downloads/usenet/incomplete 0775 olafkfreund users -"
    "d /mnt/media/downloads/usenet/queue 0775 olafkfreund users -"
    "d /mnt/media/downloads/usenet/tmp 0775 olafkfreund users -"
    "d /mnt/media/Media/Downloads 0755 olafkfreund users -"
    # AudioBookshelf directories
    "d /mnt/media/Media/Audiobooks 0755 olafkfreund users -"
    "d /mnt/media/Media/Podcasts 0755 olafkfreund users -"
    "d /mnt/media/audiobookshelf 0755 olafkfreund users -"
    # SABnzbd isolated working dirs (side-by-side trial with NZBGet)
    "d /mnt/media/downloads/sabnzbd 0775 olafkfreund users -"
    "d /mnt/media/downloads/sabnzbd/incomplete 0775 olafkfreund users -"
    "d /mnt/media/downloads/sabnzbd/complete 0775 olafkfreund users -"
    "d /mnt/media/downloads/sabnzbd/watch 0775 olafkfreund users -"
  ];

  # Easynews credentials for SABnzbd, merged into its config at runtime via
  # services.sabnzbd.secretFiles. Readable by the sabnzbd service user.
  age.secrets."sabnzbd-secrets" = {
    file = ../../../secrets/sabnzbd-secrets.age;
    mode = "0400";
    owner = "olafkfreund";
    group = "users";
  };

  # Ensure media services start before Tailscale Serve to prevent port conflicts
  systemd.services.tailscale-serve = {
    after = [ "overseerr.service" "audiobookshelf.service" "sabnzbd.service" ];
    wants = [ "overseerr.service" "audiobookshelf.service" "sabnzbd.service" ];
  };

  # Note: Firewall ports are now comprehensively configured in configuration.nix
  # This includes all media services, Plex discovery, NFS, and monitoring exporters
  # with Tailscale trustedInterfaces configuration
}
