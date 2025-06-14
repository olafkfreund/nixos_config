{
  pkgs,
  lib,
  nixpkgs,
  ...
}: let
  # Test configurations for validation
  testLib = {
    # Create a minimal test configuration
    mkTestConfig = modules: {
      imports =
        modules
        ++ [
          # Add minimal required configuration
          {
            boot.loader.grub.enable = false;
            boot.loader.systemd-boot.enable = true;
            boot.loader.efi.canTouchEfiVariables = true;

            fileSystems."/" = {
              device = "/dev/disk/by-label/nixos";
              fsType = "ext4";
            };

            users.users.testuser = {
              isNormalUser = true;
              extraGroups = ["wheel"];
            };
          }
        ];
    };

    # Validate that a configuration builds
    validateConfig = config: let
      result = nixpkgs.lib.evalModules {
        modules = [config];
      };
    in
      result.config.system.build.toplevel;
  };

  # Test scenarios
  tests = {
    # Test base profile
    base-profile = testLib.mkTestConfig [
      ../profiles/base.nix
      {
        custom.base.enable = true;
      }
    ];

    # Test desktop profile
    desktop-profile = testLib.mkTestConfig [
      ../profiles/base.nix
      ../profiles/desktop.nix
      {
        custom.base.enable = true;
        custom.desktop.enable = true;
      }
    ];

    # Test development profile
    development-profile = testLib.mkTestConfig [
      ../profiles/base.nix
      ../profiles/desktop.nix
      ../profiles/development.nix
      {
        custom.base.enable = true;
        custom.desktop.enable = true;
        custom.development.enable = true;
      }
    ];

    # Test hardware profiles
    amd-workstation = testLib.mkTestConfig [
      ../profiles/base.nix
      ../modules/hardware/profiles/amd-workstation.nix
      {
        custom.base.enable = true;
        custom.hardware.profile = "amd-workstation";
      }
    ];

    intel-laptop = testLib.mkTestConfig [
      ../profiles/base.nix
      ../modules/hardware/profiles/intel-laptop.nix
      {
        custom.base.enable = true;
        custom.hardware.profile = "intel-laptop";
      }
    ];
  };

  # Validation functions
  validators = {
    # Check that all required options are defined
    checkRequiredOptions = config: let
      requiredPaths = [
        "users.users"
        "boot.loader"
        "fileSystems"
      ];
    in
      lib.all (path: lib.hasAttrByPath (lib.splitString "." path) config) requiredPaths;

    # Check that conflicting options aren't enabled
    checkConflicts = config: let
      conflicts = [
        {
          options = ["hardware.pulseaudio.enable" "services.pipewire.enable"];
          message = "PulseAudio and PipeWire cannot be enabled simultaneously";
        }
      ];
    in
      lib.all (
        conflict: let
          enabledOptions = lib.filter (opt: lib.getAttrFromPath (lib.splitString "." opt) config) conflict.options;
        in
          lib.length enabledOptions <= 1
      )
      conflicts;

    # Check that services have their dependencies
    checkDependencies = config: let
      serviceDeps = {
        "services.greetd" = ["security.polkit"];
        "programs.hyprland" = ["xdg.portal"];
      };
    in
      lib.all (
        service:
          if lib.getAttrFromPath (lib.splitString "." service) config
          then lib.all (dep: lib.getAttrFromPath (lib.splitString "." dep) config) (serviceDeps.${service} or [])
          else true
      ) (lib.attrNames serviceDeps);
  };
in {
  inherit testLib tests validators;

  # Run all tests
  runTests =
    lib.mapAttrs (name: config: {
      builds = builtins.tryEval (testLib.validateConfig config);
      validOptions = validators.checkRequiredOptions config;
      noConflicts = validators.checkConflicts config;
      dependenciesMet = validators.checkDependencies config;
    })
    tests;
}
