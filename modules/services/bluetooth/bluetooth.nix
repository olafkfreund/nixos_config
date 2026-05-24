_: {
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings = {
      General = {
        Enable = "Source,Sink,Media,Socket";
      };
    };
  };

  services.blueman.enable = true;

  # Removed duplicate mpris-proxy service definition
  # The service is already enabled via home.media.mpd configuration
}
