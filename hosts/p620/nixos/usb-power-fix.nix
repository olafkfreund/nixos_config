{ pkgs, ... }: {
  # Fix USB and Bluetooth mouse disconnection issues
  services.udev.extraRules = ''
    # Disable autosuspend for TP-Link Bluetooth adapter (causes mouse freezing)
    ACTION=="add", SUBSYSTEM=="usb", ATTRS{idVendor}=="2357", ATTRS{idProduct}=="0604", ATTR{power/autosuspend}="-1"

    # Disable autosuspend for all Bluetooth class devices
    ACTION=="add", SUBSYSTEM=="usb", ATTRS{bDeviceClass}=="e0", ATTR{power/autosuspend}="-1"

    # Disable autosuspend for HID devices (mice, keyboards)
    ACTION=="add", SUBSYSTEM=="usb", ATTRS{bInterfaceClass}=="03", ATTR{power/autosuspend}="-1"

    # Razer Basilisk X HyperSpeed - prevent power management issues
    ACTION=="add", SUBSYSTEM=="bluetooth", ATTRS{name}=="Basilisk X HyperSpeed*", ATTR{power/control}="on"
    ACTION=="add", SUBSYSTEM=="input", ATTRS{name}=="Basilisk X HyperSpeed*", ATTR{power/control}="on"

    # Keep all Bluetooth HID devices powered on
    ACTION=="add", SUBSYSTEM=="bluetooth", KERNEL=="hci[0-9]*", RUN+="${pkgs.bash}/bin/bash -c 'echo on > /sys$devpath/power/control'"

    # Prevent Razer mouse from sleeping
    ACTION=="add", KERNEL=="hidraw*", ATTRS{name}=="Basilisk X HyperSpeed*", ATTR{power/control}="on"
  '';

  # Completely disable USB autosuspend
  boot.kernelParams = [
    "usbcore.autosuspend=-1" # Completely disable USB autosuspend
    "bluetooth.disable_ertm=1" # Disable Enhanced Retransmission Mode (can cause lag)
  ];

  # Bluetooth power management improvements
  systemd.services.bluetooth.serviceConfig = {
    Restart = "always";
    RestartSec = "5";
  };

  # Disable runtime PM for Bluetooth completely
  powerManagement.powertop.enable = false;
}
