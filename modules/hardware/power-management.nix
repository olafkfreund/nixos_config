{
  config,
  lib,
  pkgs,
  ...
}: {
  options.modules.hardware.power-management = {
    enable = lib.mkEnableOption "advanced power management";

    profile = lib.mkOption {
      type = lib.types.enum ["balanced" "performance" "powersave"];
      default = "balanced";
      description = "Power management profile";
    };

    cpu = {
      governor = lib.mkOption {
        type = lib.types.enum ["ondemand" "performance" "powersave" "conservative"];
        default = "ondemand";
        description = "CPU frequency governor";
      };

      turbo = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable CPU turbo boost";
      };
    };

    suspend = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable suspend/hibernate support";
      };
    };
  };

  config = lib.mkIf config.modules.hardware.power-management.enable {
    # CPU frequency scaling
    powerManagement = {
      enable = true;
      cpuFreqGovernor = config.modules.hardware.power-management.cpu.governor;
    };

    # Power profiles daemon (for modern power management)
    services.power-profiles-daemon.enable = lib.mkDefault true;

    # TLP power management (alternative to power-profiles-daemon)
    services.tlp = lib.mkIf (!config.services.power-profiles-daemon.enable) {
      enable = true;
      settings = lib.mkMerge [
        {
          CPU_SCALING_GOVERNOR_ON_AC =
            if config.modules.hardware.power-management.profile == "performance"
            then "performance"
            else "ondemand";
          CPU_SCALING_GOVERNOR_ON_BAT =
            if config.modules.hardware.power-management.profile == "powersave"
            then "powersave"
            else "ondemand";
        }
        (lib.mkIf (!config.modules.hardware.power-management.cpu.turbo) {
          CPU_BOOST_ON_AC = 0;
          CPU_BOOST_ON_BAT = 0;
        })
      ];
    };

    # Suspend and hibernate
    systemd.sleep.extraConfig = lib.mkIf config.modules.hardware.power-management.suspend.enable ''
      HibernateDelaySec=30m
      SuspendState=mem
    '';

    # Kernel parameters for power management
    boot.kernelParams =
      lib.optionals
      (config.modules.hardware.power-management.profile == "powersave") [
        "intel_pstate=passive"
        "processor.max_cstate=5"
      ];
  };
}
