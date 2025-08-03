{
  config,
  lib,
  pkgs,
  ...
}: {
  # Trackpad and input device optimization - using updated option names
  services.libinput = {
    enable = true; # Previously services.xserver.libinput.enable
    touchpad = {
      tapping = true;
      naturalScrolling = true;
      scrollMethod = "twofinger";
      disableWhileTyping = false;
      clickMethod = "clickfinger";
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
    users = ["olafkfreund"]; # Adjust to your username
    syncEffectsEnabled = true;
    devicesOffOnScreensaver = true;
    batteryNotifier = {
      enable = true;
      frequency = 600;
      percentage = 33;
    };
  };

  # Add Razer utilities
  # Razer hardware packages moved to main configuration.nix for consolidation

  # Support for closing lid
  services.logind = {
    lidSwitch = lib.mkDefault "suspend";
    lidSwitchExternalPower = "ignore";
  };
}
