{
  config,
  lib,
  pkgs,
  ...
}: {
  # Trackpad and input device optimization
  services.xserver.libinput = {
    enable = true;
    touchpad = {
      accelProfile = "adaptive";
      accelSpeed = "0.5";
      naturalScrolling = true;
      tapping = true;
      tappingDragLock = false;
      disableWhileTyping = true;
    };
  };

  # Backlight control
  programs.light.enable = true;
  services.actkbd = {
    enable = true;
    bindings = [
      # Add key bindings for brightness control
      {
        keys = [224];
        events = ["key"];
        command = "${pkgs.light}/bin/light -U 5";
      }
      {
        keys = [225];
        events = ["key"];
        command = "${pkgs.light}/bin/light -A 5";
      }
    ];
  };

  # Fan control and thermal management for Razer
  boot.extraModprobeConfig = ''
    options i915 enable_fbc=1 enable_guc=2
  '';

  # Battery optimization
  services.upower = {
    enable = true;
    criticalPowerAction = "Hibernate";
  };

  # Razer-specific utilities
  hardware.openrazer = {
    enable = true;
    users = ["olafkfreund"]; # Replace with your username
  };

  # Add Razer utilities
  environment.systemPackages = with pkgs; [
    polychromatic # GUI for Razer devices
    razergenie # Another Razer configuration tool
  ];

  # Support for closing lid
  services.logind = {
    lidSwitch = "suspend";
    lidSwitchExternalPower = "ignore";
  };
}
