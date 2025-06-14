{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.custom.hardware;
in {
  config = lib.mkIf (cfg.profile or null == "intel-laptop") {
    # Intel GPU drivers
    hardware.opengl = {
      enable = true;
      driSupport = true;
      driSupport32Bit = true;
      extraPackages = with pkgs; [
        intel-media-driver
        intel-vaapi-driver
        libvdpau-va-gl
      ];
    };

    # Intel CPU optimizations
    hardware.cpu.intel.updateMicrocode = true;

    # Laptop-specific hardware
    hardware = {
      bluetooth = {
        enable = true;
        powerOnBoot = true;
      };

      # Touchpad support
      libinput = {
        enable = true;
        touchpad = {
          tapping = true;
          naturalScrolling = true;
          middleEmulation = true;
        };
      };
    };

    # Power management for laptops
    services.thermald.enable = true;
    services.auto-cpufreq.enable = true;

    # TLP for battery optimization
    services.tlp = {
      enable = true;
      settings = {
        CPU_SCALING_GOVERNOR_ON_AC = "performance";
        CPU_SCALING_GOVERNOR_ON_BAT = "powersave";

        CPU_ENERGY_PERF_POLICY_ON_AC = "performance";
        CPU_ENERGY_PERF_POLICY_ON_BAT = "balance_power";

        START_CHARGE_THRESH_BAT0 = 20;
        STOP_CHARGE_THRESH_BAT0 = 80;
      };
    };

    # Backlight control
    programs.light.enable = true;

    # Laptop-specific packages
    environment.systemPackages = with pkgs; [
      acpi
      powertop
      brightnessctl
    ];

    # Set hardware configuration
    custom.hardware = {
      cpu.vendor = "intel";
      gpu.vendor = "intel";
      laptop.enable = true;
      power.management = true;
    };
  };
}
