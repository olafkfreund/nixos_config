{lib}: let
  inherit (lib) mkOption types;
in {
  # Hardware profile definitions
  hardwareProfiles = {
    amd-workstation = {
      description = "AMD-based workstation";
      config = {
        custom.hardware = {
          cpu.vendor = "amd";
          gpu.vendor = "amd";
          performance.high = true;
        };
      };
    };

    intel-laptop = {
      description = "Intel-based laptop";
      config = {
        custom.hardware = {
          cpu.vendor = "intel";
          gpu.vendor = "intel";
          laptop.enable = true;
          power.management = true;
        };
      };
    };

    nvidia-gaming = {
      description = "NVIDIA gaming system";
      config = {
        custom.hardware = {
          gpu.vendor = "nvidia";
          gaming.optimizations = true;
          cuda.enable = true;
        };
      };
    };

    hybrid-laptop = {
      description = "Laptop with hybrid graphics";
      config = {
        custom.hardware = {
          gpu.vendor = "hybrid";
          laptop.enable = true;
          power.management = true;
        };
      };
    };

    htpc-intel = {
      description = "HTPC with Intel graphics";
      config = {
        custom.hardware = {
          cpu.vendor = "intel";
          gpu.vendor = "intel";
          media.acceleration = true;
          power.efficiency = true;
        };
      };
    };
  };

  # Hardware option declarations
  hardwareOptions = {
    custom.hardware = {
      cpu = {
        vendor = mkOption {
          type = types.enum ["intel" "amd"];
          description = "CPU vendor";
        };

        cores = mkOption {
          type = types.int;
          default = 4;
          description = "Number of CPU cores";
        };

        optimizations = mkOption {
          type = types.bool;
          default = true;
          description = "Enable CPU-specific optimizations";
        };
      };

      gpu = {
        vendor = mkOption {
          type = types.enum ["intel" "amd" "nvidia" "hybrid"];
          description = "GPU vendor";
        };

        acceleration = mkOption {
          type = types.bool;
          default = true;
          description = "Enable hardware acceleration";
        };

        cuda = mkOption {
          type = types.bool;
          default = false;
          description = "Enable CUDA support";
        };
      };

      laptop = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = "Enable laptop-specific features";
        };

        touchpad = mkOption {
          type = types.bool;
          default = true;
          description = "Enable touchpad support";
        };

        backlight = mkOption {
          type = types.bool;
          default = true;
          description = "Enable backlight control";
        };
      };

      power = {
        management = mkOption {
          type = types.bool;
          default = false;
          description = "Enable power management";
        };

        efficiency = mkOption {
          type = types.bool;
          default = false;
          description = "Optimize for power efficiency";
        };
      };

      gaming = {
        optimizations = mkOption {
          type = types.bool;
          default = false;
          description = "Enable gaming optimizations";
        };
      };

      media = {
        acceleration = mkOption {
          type = types.bool;
          default = false;
          description = "Enable media hardware acceleration";
        };
      };
    };
  };
}
