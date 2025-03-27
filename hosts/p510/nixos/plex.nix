{
  pkgs-unstable,
  config,
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

    # ombi = {
    #   enable = true;
    #   user = "olafkfreund";
    #   dataDir = "/mnt/media/ombi";
    #   package = pkgs-unstable.ombi;
    # };

    lidarr = {
      enable = true;
      user = "olafkfreund";
      dataDir = "/mnt/media/lidarr";
      package = pkgs-unstable.lidarr;
    };

    # nzbhydra2 = {
    #   enable = true;
    #   dataDir = "/mnt/media/nzbhydra2";
    #   package = pkgs-unstable.nzbhydra2;
    # };

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

    nfs.server = {
      enable = true;
      exports = ''
        /mnt/media         *(rw,fsid=0,no_subtree_check)
      '';
    };
  };
}
