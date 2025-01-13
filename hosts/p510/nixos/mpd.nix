{
  config,
  lib,
  ...
}: {
  services.mpd = {
    enable = true;
    musicDirectory = "/mnt/media/Media/Music";
    user = "olafkfreund";
    environment = {
      XDG_RUNTIME_DIR = "/run/user/${toString config.users.users.olafkfreund.uid}";
    };
    extraConfig = ''
      audio_output {
      type "pipewire"
      name "MPD Output"
      }
    '';

    # Optional:
    network.listenAddress = "any"; # if you want to allow non-localhost connections
    network.startWhenNeeded = true; # systemd feature: only start MPD service upon connection to its socket
  };
}
