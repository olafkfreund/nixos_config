{ lib
, pkgs
, ...
}: {
  # Backlight control
  programs.light.enable = true;

  # Fan control and thermal management for Samsung laptop
  boot.extraModprobeConfig = ''
    options i915 enable_fbc=1 enable_guc=2
  '';

  # All services combined to avoid repeated keys
  services = {
    # Trackpad and input device optimization
    libinput = {
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

    # Brightness control key bindings
    actkbd = {
      enable = true;
      bindings = [
        {
          keys = [ 224 ];
          events = [ "key" ];
          command = "${pkgs.light}/bin/light -U 5";
        }
        {
          keys = [ 225 ];
          events = [ "key" ];
          command = "${pkgs.light}/bin/light -A 5";
        }
      ];
    };

    # Battery optimization
    upower = {
      enable = true;
      criticalPowerAction = "Hibernate";
    };

    # Support for closing lid
    logind.settings.Login = {
      HandleLidSwitch = lib.mkDefault "suspend";
      HandleLidSwitchExternalPower = "ignore";
    };
  };
}
