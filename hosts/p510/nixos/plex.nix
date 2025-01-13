{pkgs-unstable, ...}: {
  services = {
    plex = {
      enable = true;
      user = "olafkfreund";
      accelerationDevices = ["*"];
      dataDir = "/mnt/media/plex";
      package = pkgs-unstable.plex;
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
      package = pkgs-unstable.transmission_4;
      settings = {
        trash-original-torrent-files = true;
        rpc-bind-address = "0.0.0.0";
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
