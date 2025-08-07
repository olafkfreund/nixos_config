{ ...
}: {
  services.mpd = {
    enable = true;
    musicDirectory = "/mnt/media/Media/Music";
    user = "olafkfreund";
    extraConfig = ''
      audio_output {
        type "pipewire"
        name "PipeWire Sound Server"
      }
    '';
    network.listenAddress = "any"; # if you want to allow non-localhost connections
    startWhenNeeded = true; # systemd feature: only start MPD service upon connection to its socket
  };
  systemd.services.mpd.environment = {
    XDG_RUNTIME_DIR = "/run/user/1000";
  };
}
