{
  config,
  lib,
  ...
}: {
  services.mpd = {
    enable = true;
    musicDirectory = "/mnt/media/Media/Music";
    user = "olafkfreund";
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
  systemd.services.mpd.environment = {
    XDG_RUNTIME_DIR = "/run/user/${toString config.users.users.olafkfreund.uid}"; # User-id must match above user. MPD will look inside this directory for the PipeWire socket.
  };
}
