{ ...
}: {
  # Fix USB mouse freezing by disabling autosuspend for Bluetooth devices
  services.udev.extraRules = ''
    # Disable autosuspend for TP-Link Bluetooth adapter (causes mouse freezing)
    ACTION=="add", SUBSYSTEM=="usb", ATTRS{idVendor}=="2357", ATTRS{idProduct}=="0604", ATTR{power/autosuspend}="-1"
    
    # Disable autosuspend for all Bluetooth class devices
    ACTION=="add", SUBSYSTEM=="usb", ATTRS{bDeviceClass}=="e0", ATTR{power/autosuspend}="-1"
    
    # Disable autosuspend for HID devices (mice, keyboards)
    ACTION=="add", SUBSYSTEM=="usb", ATTRS{bInterfaceClass}=="03", ATTR{power/autosuspend}="-1"
  '';

  # Alternative: Increase global USB autosuspend delay
  boot.kernelParams = [
    "usbcore.autosuspend=30" # Increase from 2 to 30 seconds
  ];

  # Bluetooth power management improvements
  systemd.services.bluetooth.serviceConfig = {
    Restart = "always";
    RestartSec = "5";
  };
}
