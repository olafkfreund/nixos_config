{
  lib,
  pkgs,
  ...
}: {
  # Trackpad and input device optimization - using updated option names
  services.libinput = {
    enable = true; # Previously services.xserver.libinput.enable
    touchpad = {
      # Previously services.xserver.libinput.touchpad
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

  # Support for closing lid
  services.logind = {
    lidSwitch = lib.mkDefault "suspend";
    lidSwitchExternalPower = "ignore";
  };
}
