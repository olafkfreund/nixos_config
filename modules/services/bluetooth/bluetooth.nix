_: {
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings = {
      General = {
        Enable = "Source,Sink,Media,Socket";
        # Battery reporting (org.bluez.Battery1) is still gated behind
        # BlueZ's experimental flag. Without it a headset's charge level is
        # simply absent -- from the Omarchy bar, from blueman, and from
        # pbpctrl, which names it as a requirement. Applies fleet-wide
        # because the gain (battery levels for every BT device) is not
        # razer-specific.
        Experimental = true;
      };
    };
  };

  services.blueman.enable = true;

  # Removed duplicate mpris-proxy service definition
  # The service is already enabled via home.media.mpd configuration
}
