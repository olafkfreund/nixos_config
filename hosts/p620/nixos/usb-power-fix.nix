{ pkgs, lib, ... }: {
  # Fix USB and Bluetooth mouse disconnection issues
  services.udev.extraRules = ''
    # Disable autosuspend for TP-Link Bluetooth adapter (causes mouse freezing)
    ACTION=="add", SUBSYSTEM=="usb", ATTRS{idVendor}=="2357", ATTRS{idProduct}=="0604", ATTR{power/autosuspend}="-1", ATTR{power/control}="on"

    # Disable autosuspend for all Bluetooth class devices
    ACTION=="add", SUBSYSTEM=="usb", ATTRS{bDeviceClass}=="e0", ATTR{power/autosuspend}="-1", ATTR{power/control}="on"

    # Disable autosuspend for HID devices (mice, keyboards)
    ACTION=="add", SUBSYSTEM=="usb", ATTRS{bInterfaceClass}=="03", ATTR{power/autosuspend}="-1", ATTR{power/control}="on"

    # Disable autosuspend for all Razer devices
    ACTION=="add", SUBSYSTEM=="usb", ATTRS{idVendor}=="1532", ATTR{power/autosuspend}="-1", ATTR{power/control}="on"

    # Razer Basilisk X HyperSpeed - prevent power management issues (both USB and Bluetooth)
    ACTION=="add", SUBSYSTEM=="usb", ATTRS{idVendor}=="1532", ATTRS{idProduct}=="0083", ATTR{power/autosuspend}="-1", ATTR{power/control}="on"
    ACTION=="add", SUBSYSTEM=="bluetooth", ATTRS{name}=="Basilisk X HyperSpeed*", ATTR{power/control}="on"
    ACTION=="add", SUBSYSTEM=="input", ATTRS{name}=="Basilisk X HyperSpeed*", ATTR{power/control}="on"

    # Keep all Bluetooth HID devices powered on
    ACTION=="add", SUBSYSTEM=="bluetooth", KERNEL=="hci[0-9]*", RUN+="${pkgs.bash}/bin/bash -c 'echo on > /sys$devpath/power/control'"

    # Prevent Razer mouse from sleeping
    ACTION=="add", KERNEL=="hidraw*", ATTRS{name}=="Basilisk X HyperSpeed*", ATTR{power/control}="on"

    # Disable autosuspend for ALL USB hubs to prevent downstream devices from disconnecting
    ACTION=="add", SUBSYSTEM=="usb", ATTR{bDeviceClass}=="09", ATTR{power/autosuspend}="-1", ATTR{power/control}="on"
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

  # Disable ACPID input device monitoring to prevent disconnect events
  services.acpid.enable = lib.mkForce false;

  # Disable runtime PM for Bluetooth completely
  powerManagement = {
    powertop.enable = false;
  };

  # Prevent systemd-rfkill from blocking Bluetooth
  systemd.services.systemd-rfkill.enable = lib.mkForce false;

  # Ensure Bluetooth is always unblocked at boot
  systemd.services.bluetooth-unblock = {
    description = "Unblock Bluetooth adapter at boot";
    wantedBy = [ "bluetooth.service" ];
    before = [ "bluetooth.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      ${pkgs.util-linux}/bin/rfkill unblock bluetooth
    '';
  };

  # Systemd service to force all USB devices to stay powered on
  systemd.services.usb-power-on = {
    description = "Force all USB devices to stay powered on";
    wantedBy = [ "multi-user.target" ];
    after = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      for dev in /sys/bus/usb/devices/*/power/control; do
        if [ -f "$dev" ]; then
          echo "on" > "$dev" || true
        fi
      done
      for dev in /sys/bus/usb/devices/*/power/autosuspend; do
        if [ -f "$dev" ]; then
          echo "-1" > "$dev" || true
        fi
      done
    '';
  };
}
