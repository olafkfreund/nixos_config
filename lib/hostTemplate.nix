# Host configuration template system
{ lib
, pkgs
, ...
}: {
  # Host types with default configurations
  hostTypes = {
    workstation = {
      featureProfiles.workstation = true;
      features = {
        graphics.enable = true;
        audio.enable = true;
        networking.enable = true;
      };
      hardware.enableRedistributableFirmware = true;
      services.xserver.enable = true;
    };

    laptop = {
      featureProfiles.workstation = true;
      features = {
        graphics.enable = true;
        audio.enable = true;
        networking.enable = true;
        power.enable = true; # Power management for laptops
      };
      hardware = {
        enableRedistributableFirmware = true;
        bluetooth.enable = true;
      };
      services = {
        xserver.enable = true;
        tlp.enable = true; # Power management
      };
    };

    server = {
      featureProfiles.server = true;
      features = {
        networking.enable = true;
        security.enable = true;
      };
      # Minimal server setup
      services.openssh.enable = true;
      networking.firewall.enable = true;
    };

    gaming = {
      featureProfiles.gaming = true;
      features = {
        graphics.enable = true;
        audio.enable = true;
        gaming.enable = true;
      };
      hardware = {
        enableRedistributableFirmware = true;
        opengl.enable = true;
      };
      programs.steam.enable = true;
    };
  };

  # Hardware profiles
  hardwareProfiles = {
    nvidia = {
      hardware.nvidia = {
        modesetting.enable = true;
        powerManagement.enable = true;
        open = false; # Use proprietary driver
      };
      services.xserver.videoDrivers = [ "nvidia" ];
    };

    amd = {
      hardware.opengl = {
        enable = true;
        driSupport = true;
        driSupport32Bit = true;
        extraPackages = with pkgs; [
          rocm-opencl-icd
          rocm-opencl-runtime
        ];
      };
    };

    intel = {
      hardware.opengl = {
        enable = true;
        driSupport = true;
        driSupport32Bit = true;
        extraPackages = with pkgs; [
          intel-media-driver
          vaapiIntel
          vaapiVdpau
          # libvdpau-va-gl removed - old unmaintained package with CMake compatibility issues
          # Modern Intel systems work perfectly with intel-media-driver and vaapiIntel
        ];
      };
    };
  };

  # Generate host configuration
  mkHost =
    { hostTypes
    , hardwareProfiles
    ,
    }: hostName: { type ? "workstation"
                 , hardware ? [ ]
                 , users ? [ "olafkfreund" ]
                 , extraConfig ? { }
                 , variables ? { }
                 ,
                 }:
    let
      baseConfig = hostTypes.${type} or { };
      hardwareConfig = lib.foldl' lib.recursiveUpdate { } (
        map (hw: hardwareProfiles.${hw} or { }) hardware
      );
    in
    lib.recursiveUpdate (lib.recursiveUpdate baseConfig hardwareConfig) (extraConfig
      // {
      networking.hostName = hostName;

      # User configuration
      users.users = lib.genAttrs users (user: {
        isNormalUser = true;
        description = variables.fullName or user;
        extraGroups = variables.userGroups or [ "wheel" "networkmanager" ];
        shell = pkgs.zsh;
      });

      # Import host-specific configuration
      imports =
        [
          ./hosts/${hostName}/hardware-configuration.nix
          ./hosts/${hostName}/variables.nix
        ]
        ++ (
          if builtins.pathExists ./hosts/${hostName}/themes/stylix.nix
          then [ ./hosts/${hostName}/themes/stylix.nix ]
          else [ ]
        );
    });
}
