{pkgs-unstable, ...}: {
  services.plex = {
    enable = true;
    user = "olafkfreund";
    accelerationDevices = ["*"];
    dataDir = "/mnt/media/plex";
    package = pkgs-unstable.plex;
  };
  services.nzbget = {
    enable = true;
    user = "olafkfreund";
    package = pkgs-unstable.nzbget;
  };
  services.radarr = {
    enable = true;
    user = "olafkfreund";
    dataDir = "/mnt/media/radarr";
    package = pkgs-unstable.radarr;
  };
  services.sonarr = {
    enable = true;
    user = "olafkfreund";
    dataDir = "/mnt/media/sonarr";
    package = pkgs-unstable.sonarr;
  };
  services.tautulli = {
    enable = true;
    user = "olafkfreund";
    dataDir = "/mnt/media/tautulli";
    package = pkgs-unstable.tautulli;
  };
  # services.ombi = {
  #   enable = true;
  #   user = "olafkfreund";
  #   dataDir = "/mnt/media/ombi";
  #   package = pkgs-unstable.ombi;
  # };
  services.lidarr = {
    enable = true;
    user = "olafkfreund";
    dataDir = "/mnt/media/lidarr";
    package = pkgs-unstable.lidarr;
  };
  # services.nzbhydra2 = {
  #   enable = true;
  #   dataDir = "/mnt/media/nzbhydra2";
  #   package = pkgs-unstable.nzbhydra2;
  # };
  services.transmission = {
    enable = true;
    user = "olafkfreund";
    package = pkgs-unstable.transmission_4;
    settings = {
      trash-original-torrent-files = true;
    };
  };
  services.nfs.server.enable = true;
  # services.nfs.server.exports = ''
  #   /export         192.168.1.10(rw,fsid=0,no_subtree_check) 192.168.1.15(rw,fsid=0,no_subtree_check)
  #   /export/kotomi  192.168.1.10(rw,nohide,insecure,no_subtree_check) 192.168.1.15(rw,nohide,insecure,no_subtree_check)
  #   /export/mafuyu  192.168.1.10(rw,nohide,insecure,no_subtree_check) 192.168.1.15(rw,nohide,insecure,no_subtree_check)
  #   /export/sen     192.168.1.10(rw,nohide,insecure,no_subtree_check) 192.168.1.15(rw,nohide,insecure,no_subtree_check)
  #   /export/tomoyo  192.168.1.10(rw,nohide,insecure,no_subtree_check) 192.168.1.15(rw,nohide,insecure,no_subtree_check)
  # '';
}
