{ ... }: {
  services.plex = {
    enable = true;
    user = "olafkfreund";
    accelerationDevices = [ "*" ];
    dataDir = "/mnt/media/plex";
  };
  services.nzbget = {
    enable = true;
    user = "olafkfreund";
  };
  services.radarr = {
    enable = true;
    user  = "olafkfreund";
    dataDir = "/mnt/media/radarr";
  };
  services.sonarr = {
    enable = true; 
    user = "olafkfreund";
    dataDir = "/mnt/media/sonarr";
  };
  services.jackett = {
    enable = true;
    user = "olafkfreund";
    dataDir = "/mnt/media/jackett";
  };
  services.tautulli = {
    enable = true;
    user = "olafkfreund";
    dataDir = "/mnt/media/tautulli";
  };
  services.ombi = {
    enable = true;
    user = "olafkfreund";
    dataDir = "/mnt/media/ombi";
  };
  services.lidarr = {
    enable = true;
    user = "olafkfreund";
    dataDir = "/mnt/media/lidarr";
  };
  services.nzbhydra2 = {
    enable = true;
    dataDir = "/mnt/media/nzbhydra2";
  };
  services.transmission = {
    enable = true;
    user = "olafkfreund";
    settings = {
      trash-original-torrent-files = true;
    };
  };
}
