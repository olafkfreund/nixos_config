{
  description = "Olaf's flake with Home Manager enabled";

  nixConfig = {
    # Primary caches
    substituters = [
      "https://cache.nixos.org/"
      "https://nix-community.cachix.org"
      #"http://192.168.1.97:5000"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "p620-nix-serve:mZR6o5z5KcWeu4PVXgjHA7vb1sHQgRdWMKQt8x3a4rU="
    ];

    # Development and specific package caches
    extra-substituters = [
      "https://cuda-maintainers.cachix.org"
      "https://hyprland.cachix.org"
      "https://devenv.cachix.org"
      "https://cosmic.cachix.org/"
      "https://cache.saumon.network/proxmox-nixos"
      "https://walker-git.cachix.org"
      "https://walker.cachix.org"
      "http://192.168.1.97:5000"
    ];
    extra-trusted-public-keys = [
      "cuda-maintainers.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUDZ9JyUG0VpVZa7CNfq5E="
      "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
      "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw="
      "cosmic.cachix.org-1:Dya9IyXD4xdBehWjrkPv6rtxpmMdRel02smYzA85dPE="
      "walker-git.cachix.org-1:vmC0ocfPWh0S/vRAQGtChuiZBTAe4wiKDeyyXM0/7pM="
      "walker.cachix.org-1:fG8q+uAaMqhsMxWjwvk0IMb4mFPFLqHjuvfwQxE4oJM="
      "p620-nix-serve:mZR6o5z5KcWeu4PVXgjHA7vb1sHQgRdWMKQt8x3a4rU="
    ];
  };

  inputs = {
    # Core
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-25.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    flake-utils.url = "github:numtide/flake-utils";

    # Environment and theming
    home-manager.url = "github:nix-community/home-manager";
    nix-colors.url = "github:misterio77/nix-colors";
    stylix.url = "github:danth/stylix";

    # Editor

    # Development and utilities
    sops-nix = {
      url = "github:mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Applications and specific tools
    claude-desktop = {
      url = "github:k3d3/claude-desktop-linux-flake";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
    };

    # Desktop environment
    hyprland = {
      url = "github:hyprwm/Hyprland";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Browser and media
    spicetify-nix.url = "github:Gerg-L/spicetify-nix";

    # System utilities
    agenix.url = "github:ryantm/agenix";
    nix-snapd.url = "github:io12/nix-snapd";
    microvm.url = "github:astro/microvm.nix";

    # Secure Boot
    lanzaboote = {
      url = "github:nix-community/lanzaboote/v0.4.1";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Additional tools
    lan-mouse.url = "github:feschber/lan-mouse";
    # walker.url = "github:abenz1267/walker"; # Temporarily disabled - flake.nix missing
    zjstatus.url = "github:dj95/zjstatus";

    # Terminal YouTube browser
    yt-x = {
      url = "github:Benexl/yt-x";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Hardware specific
    razer-laptop-control.url = "github:Razer-Linux/razer-laptop-control-no-dkms";

    # Package collections
    nur.url = "github:nix-community/NUR";
    nixpkgs-f2k.url = "github:moni-dz/nixpkgs-f2k";
    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixai.url = "github:olafkfreund/nix-ai-help";
  };

  outputs =
    { nixpkgs
    , nixpkgs-stable
    , nixpkgs-unstable
    , nur
    , nixai
    , agenix
    , lanzaboote
    , razer-laptop-control
    , nix-colors
    , nix-snapd
    , spicetify-nix
    , home-manager
    , stylix
    , nix-index-database
    , zjstatus
    , ...
    } @ inputs:
    let
      # ========================================
      # SHARED ARCHITECTURE COMPONENTS
      # ========================================

      # Import centralized user mappings from shared variables
      sharedVariables = import ./hosts/common/shared-variables.nix;

      # Define users per host (can be customized per host if needed)
      hostUsers = {
        p620 = [ "olafkfreund" ];
        samsung = [ "olafkfreund" ];
        razer = [ "olafkfreund" ];
        p510 = [ "olafkfreund" ];
        dex5550 = [ "olafkfreund" ];
      };

      # Note: MicroVM packages and live images temporarily disabled during refactoring

      # ========================================
      # HELPER FUNCTIONS
      # ========================================

      # Get primary user (first in the list) for backward compatibility
      getPrimaryUser = host: builtins.head (hostUsers.${host} or [ "olafkfreund" ]);

      # Get all users for a host
      getHostUsers = host: hostUsers.${host} or [ "olafkfreund" ];

      # ========================================
      # ARCHITECTURE TEMPLATES
      # ========================================

      # Host type templates for configuration reduction (workstation, laptop, server, hybrid)
      hostTypes = import ./lib/hostTypes.nix { inherit (nixpkgs) lib; };

      # Hardware profiles for GPU-specific configurations
      hardwareProfiles = {
        amd = import ./hosts/common/hardware-profiles/amd-gpu.nix;
        nvidia = import ./hosts/common/hardware-profiles/nvidia-gpu.nix;
        intel = import ./hosts/common/hardware-profiles/intel-integrated.nix;
      };

      # ========================================
      # PACKAGE CONFIGURATION
      # ========================================

      # Helper function for package imports
      mkPkgs = _pkgs: {
        system = "x86_64-linux";
        config.allowUnfree = true;
        # config.allowInsecure = true; # REMOVED for security - using targeted permissions
      };

      # Import custom packages and overlays
      overlays = [
        (final: _prev: {
          customPkgs = import ./pkgs {
            pkgs = final;
          };
        })
        (_final: prev: {
          zjstatus = inputs.zjstatus.packages.${prev.system}.default;
        })
      ];

      makeNixosSystem = host:
        let
          primaryUser = getPrimaryUser host;
          allUsers = getHostUsers host;
          # Only import stylix for desktop/workstation hosts, not servers
          stylixModule =
            if host == "dex5550"
            then [ ]
            else [ inputs.stylix.nixosModules.stylix ];
        in
        {
          system = "x86_64-linux";
          specialArgs = {
            pkgs-stable = import nixpkgs-stable (mkPkgs nixpkgs-stable);
            pkgs-unstable = import nixpkgs-unstable (mkPkgs nixpkgs-unstable);
            inherit inputs host hostTypes;
            username = primaryUser; # Primary user for backward compatibility
            hostUsers = allUsers; # All users for this host
            # Shared variables and hardware profiles for explicit tracking
            inherit sharedVariables hardwareProfiles;
          };
          modules =
            [
              { nixpkgs.overlays = overlays; }
              ./hosts/${host}/configuration.nix
              nur.modules.nixos.default
              home-manager.nixosModules.home-manager
              inputs.nix-colors.homeManagerModules.default
              inputs.nix-snapd.nixosModules.default
              inputs.agenix.nixosModules.default
              inputs.lanzaboote.nixosModules.lanzaboote
              nix-index-database.nixosModules.nix-index
              ./home/shell/zellij/zjstatus.nix
              nixai.nixosModules.default
            ]
            ++ stylixModule
            ++ [
              {
                home-manager = {
                  useGlobalPkgs = true;
                  useUserPackages = true;
                  backupFileExtension = "backup";
                  extraSpecialArgs = {
                    pkgs-stable = import nixpkgs-stable (mkPkgs nixpkgs-stable);
                    pkgs-unstable = import nixpkgs-unstable (mkPkgs nixpkgs-unstable);
                    inherit
                      inputs
                      nixpkgs
                      zjstatus
                      spicetify-nix
                      agenix
                      razer-laptop-control
                      host
                      ;
                    username = primaryUser;
                    hostUsers = allUsers;
                    # Shared variables and hardware profiles for home-manager
                    inherit sharedVariables hardwareProfiles;
                  };
                  users = builtins.listToAttrs (map
                    (user: {
                      name = user;
                      value = import (./Users + "/${user}/${host}_home.nix");
                    })
                    allUsers);
                };
              }
            ];
        };
    in
    {
      # ========================================
      # HOST CONFIGURATIONS
      # ========================================
      nixosConfigurations = {
        # Workstations (high-performance desktop systems)
        p620 = nixpkgs.lib.nixosSystem (makeNixosSystem "p620"); # AMD workstation (primary AI host)
        p510 = nixpkgs.lib.nixosSystem (makeNixosSystem "p510"); # Intel Xeon server (media server)

        # Laptops (portable systems with power management)
        razer = nixpkgs.lib.nixosSystem (makeNixosSystem "razer"); # Intel/NVIDIA laptop (mobile dev)
        samsung = nixpkgs.lib.nixosSystem (makeNixosSystem "samsung"); # Intel laptop (mobile)

        # Servers (headless monitoring and services)
        dex5550 = nixpkgs.lib.nixosSystem (makeNixosSystem "dex5550"); # Intel SFF (monitoring server)

        # Hybrid systems (server/workstation combinations)
        # hp = nixpkgs.lib.nixosSystem (makeNixosSystem "hp"); # Currently inactive

        # MicroVM configurations (temporarily disabled for flake restructuring)
        # dev-vm = microvms.dev-vm;
        # test-vm = microvms.test-vm;
        # playground-vm = microvms.playground-vm;
      };

      # ========================================
      # PACKAGES AND APPLICATIONS
      # ========================================
      packages.x86_64-linux =
        let
          pkgs = nixpkgs.legacyPackages.x86_64-linux;
        in
        {
          # Custom applications
          claude-code = import ./home/development/claude-code {
            inherit (pkgs) lib buildNpmPackage fetchurl nodejs makeWrapper writeShellScriptBin;
          };
          codex-cli = pkgs.callPackage ./home/development/codex-cli {
            nodejs_22 = pkgs.nodejs_22;
          };
          gemini-cli = pkgs.callPackage ./pkgs/gemini-cli { };
          opencode = pkgs.callPackage ./home/development/opencode { };

          # Live ISO images (temporarily disabled during flake restructuring)
          # live-iso-p620 = liveImages.liveImages.p620.config.system.build.isoImage;
          # live-iso-razer = liveImages.liveImages.razer.config.system.build.isoImage;
          # live-iso-p510 = liveImages.liveImages.p510.config.system.build.isoImage;
          # live-iso-dex5550 = liveImages.liveImages.dex5550.config.system.build.isoImage;
          # live-iso-samsung = liveImages.liveImages.samsung.config.system.build.isoImage;

          # Development and deployment tools available as packages
          # (Apps are available separately via apps.x86_64-linux)
        };

      # ========================================
      # DEVELOPMENT ENVIRONMENTS
      # ========================================
      devShells.x86_64-linux =
        let
          pkgs = nixpkgs.legacyPackages.x86_64-linux;
        in
        {
          default = import ./tools/dev.nix { inherit pkgs inputs; };
          testing = import ./tools/testing.nix { inherit pkgs; };
          docs = import ./tools/docs.nix { inherit pkgs; };
        };

      # ========================================
      # VALIDATION AND AUTOMATION
      # ========================================

      # Quality assurance and validation checks
      checks.x86_64-linux = import ./checks/default.nix {
        pkgs = nixpkgs.legacyPackages.x86_64-linux;
        inherit (nixpkgs) lib;
      };

      # Application entries for common workflows
      apps.x86_64-linux =
        let
          pkgs = nixpkgs.legacyPackages.x86_64-linux;
          appPkgs = import ./tools/default.nix { inherit pkgs; };
        in
        {
          deploy = {
            type = "app";
            program = "${appPkgs.deploy}/bin/nixos-deploy";
          };
          test = {
            type = "app";
            program = "${appPkgs.test}/bin/nixos-test";
          };
          build-live = {
            type = "app";
            program = "${appPkgs.build-live}/bin/nixos-build-live";
          };
          dev-utils = {
            type = "app";
            program = "${appPkgs.dev-utils}/bin/nixos-dev-utils";
          };
        };

      # Code formatter for consistent formatting
      formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixpkgs-fmt;

      # ========================================
      # MODULE EXPORTS
      # ========================================

      # Module exports for reuse by other flakes
      nixosModules = {
        # Core module categories
        monitoring = ./modules/monitoring;
        ai-providers = ./modules/ai;
        development = ./modules/development;
        desktop = ./modules/desktop;

        # Feature modules
        features = ./modules/features;
        packages = ./modules/packages;

        # System modules
        core = ./modules/core.nix;
        security = ./modules/security;

        # Utility modules
        network = ./modules/network;
        virtualization = ./modules/virtualization;
      };
    };
}
