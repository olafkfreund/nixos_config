{ lib
, pkgs
, ...
}: {
  # Consolidated services configuration
  services = {
    # Trackpad and input device optimization - using updated option names
    libinput = {
      enable = true; # Previously services.xserver.libinput.enable
      touchpad = {
        tapping = true;
        naturalScrolling = true;
        scrollMethod = "twofinger";
        disableWhileTyping = false;
        clickMethod = "clickfinger";
      };
    };

    # Backlight control key bindings
    actkbd = {
      enable = true;
      bindings = [
        # Add key bindings for brightness control
        {
          keys = [ 224 ];
          events = [ "key" ];
          command = "${pkgs.brightnessctl}/bin/brightnessctl set 5%-";
        }
        {
          keys = [ 225 ];
          events = [ "key" ];
          command = "${pkgs.brightnessctl}/bin/brightnessctl set 5%+";
        }
      ];
    };

    # Battery optimization
    upower = {
      enable = true;
      criticalPowerAction = "Hibernate";
    };

    # Support for closing lid
    logind = {
      settings.Login = {
        HandleLidSwitch = lib.mkDefault "suspend";
        HandleLidSwitchExternalPower = "ignore";
      };
    };
  };

  # Backlight control + SMART tooling (see services.smartd below)
  environment.systemPackages = [ pkgs.brightnessctl pkgs.smartmontools ];

  # Fan control and thermal management for Razer
  boot.extraModprobeConfig = ''
    options i915 enable_fbc=1 enable_guc=2
  '';

  # Razer-specific utilities
  hardware.openrazer = {
    enable = true;
    users = [ "olafkfreund" ]; # Adjust to your username
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

  # SMART monitoring for the NVMe. p620 gets this from
  # storage.performanceOptimization and p510 from its resilience module, but
  # that whole storage module is p620-scoped (sysctls, tmpfs sizing), so wire
  # up just the disk-health bit here rather than dragging the rest onto a
  # laptop. A dying laptop SSD should not be a surprise.
  # (smartmontools is added to the systemPackages list above — this file
  # already defines that attribute, so it cannot be assigned twice.)
  services.smartd = {
    enable = true;
    autodetect = true;
  };
}
