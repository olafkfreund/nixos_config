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

  services.blueman = {
    enable = true;
    # Workaround for upstream nixpkgs#514705: the blueman NixOS module
    # ships a systemd unit definition that conflicts with the unit shipped
    # by the blueman package itself, causing `bad-setting` and silent
    # applet failure. Disabling the module-side unit lets users still
    # launch the applet manually (the package ships its own working unit).
    withApplet = false;
  };

  # Removed duplicate mpris-proxy service definition
  # The service is already enabled via home.media.mpd configuration
}
