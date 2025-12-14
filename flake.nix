{
  description = "Olaf's flake with Home Manager enabled";

  nixConfig = {
    # Primary caches
    substituters = [
      "https://cache.nixos.org/"
      "https://nix-community.cachix.org/"
      #"http://192.168.1.97:5000/"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "p620-nix-serve:mZR6o5z5KcWeu4PVXgjHA7vb1sHQgRdWMKQt8x3a4rU="
    ];

    # Development and specific package caches
    extra-substituters = [
      "https://cuda-maintainers.cachix.org/"
      "https://hyprland.cachix.org/"
      "https://devenv.cachix.org/"
      "https://cosmic.cachix.org/"
      "https://cache.saumon.network/proxmox-nixos/"
      "https://walker-git.cachix.org/"
      "https://walker.cachix.org/"
      "http://192.168.1.97:5000/"
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
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-colors.url = "github:misterio77/nix-colors";
    stylix = {
      url = "github:danth/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Editor

    # Development and utilities
    sops-nix = {
      url = "github:mic92/sops-nix";
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
    zjstatus.url = "github:dj95/zjstatus";
    claude-desktop-linux.url = "github:k3d3/claude-desktop-linux-flake";

    # Terminal YouTube browser
    yt-x = {
      url = "github:Benexl/yt-x";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Hardware specific (removed unused razer-laptop-control)

    # Package collections
    nur.url = "github:nix-community/NUR";
    nixpkgs-f2k.url = "github:moni-dz/nixpkgs-f2k";
    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixai.url = "github:olafkfreund/nix-ai-help";

    # Google Antigravity package
    antigravity-nix = {
      url = "github:jacopone/antigravity-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { nixpkgs
    , nixpkgs-stable
    , nixpkgs-unstable
    , nur
    , nixai
    , agenix
    , spicetify-nix
    , home-manager
    , nix-index-database
    , zjstatus
    , antigravity-nix
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
      mkPkgs = _pkgs: system: {
        inherit system;
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
          zjstatus = inputs.zjstatus.packages.${prev.stdenv.hostPlatform.system}.default;
        })
        # Claude Desktop from k3d3/claude-desktop-linux-flake (FHS version with MCP server support)
        (_final: prev: {
          claude-desktop-linux = inputs.claude-desktop-linux.packages.${prev.stdenv.hostPlatform.system}.claude-desktop-with-fhs;
        })
        # Custom package: glim - GitLab CI/CD TUI
        (final: _prev: {
          glim = final.callPackage ./overlays/glim { };
        })
        # Custom package: intune-portal - Microsoft Intune Company Portal with version control
        (final: _prev: {
          intune-portal = final.callPackage ./pkgs/intune-portal { };
        })
        # Custom package: citrix-workspace - Citrix Workspace with USB support and local tarball management
        (import ./overlays/citrix-workspace.nix)
        # Fix CMake version compatibility issues for packages requiring CMake < 3.5
        (_final: prev: {
          clblast = prev.clblast.overrideAttrs (oldAttrs: {
            cmakeFlags =
              (oldAttrs.cmakeFlags or [ ])
              ++ [
                "-DCMAKE_POLICY_VERSION_MINIMUM=3.5"
              ];
          });
          cld2 = prev.cld2.overrideAttrs (oldAttrs: {
            cmakeFlags =
              (oldAttrs.cmakeFlags or [ ])
              ++ [
                "-DCMAKE_POLICY_VERSION_MINIMUM=3.5"
              ];
          });
          ctranslate2 = prev.ctranslate2.overrideAttrs (oldAttrs: {
            cmakeFlags =
              (oldAttrs.cmakeFlags or [ ])
              ++ [
                "-DCMAKE_POLICY_VERSION_MINIMUM=3.5"
              ];
          });
          rofi-file-browser-extended = prev.rofi-file-browser-extended.overrideAttrs (oldAttrs: {
            cmakeFlags =
              (oldAttrs.cmakeFlags or [ ])
              ++ [
                "-DCMAKE_POLICY_VERSION_MINIMUM=3.5"
              ];
          });
          birdtray = prev.birdtray.overrideAttrs (oldAttrs: {
            cmakeFlags =
              (oldAttrs.cmakeFlags or [ ])
              ++ [
                "-DCMAKE_POLICY_VERSION_MINIMUM=3.5"
              ];
          });
          allegro = prev.allegro.overrideAttrs (oldAttrs: {
            cmakeFlags =
              (oldAttrs.cmakeFlags or [ ])
              ++ [
                "-DCMAKE_POLICY_VERSION_MINIMUM=3.5"
              ];
          });
          # Skip ltrace tests that fail on newer kernels
          ltrace = prev.ltrace.overrideAttrs (_oldAttrs: {
            doCheck = false;
          });
          # Fix cxxopts missing icu dependency
          cxxopts = prev.cxxopts.overrideAttrs (oldAttrs: {
            buildInputs = (oldAttrs.buildInputs or [ ]) ++ [ prev.icu ];
            propagatedBuildInputs = (oldAttrs.propagatedBuildInputs or [ ]) ++ [ prev.icu ];
          });
          # Fix pamixer missing cxxopts dependency
          pamixer = prev.pamixer.overrideAttrs (oldAttrs: {
            buildInputs = (oldAttrs.buildInputs or [ ]) ++ [ prev.cxxopts prev.icu ];
          });
        })
      ];

      makeNixosSystem = host:
        let
          primaryUser = getPrimaryUser host;
          allUsers = getHostUsers host;
          # Import stylix for all hosts (removed dex5550 check as host no longer exists)
          stylixModule = [ inputs.stylix.nixosModules.stylix ];
          system = "x86_64-linux";
        in
        {
          inherit system;
          specialArgs = {
            pkgs-stable = import nixpkgs-stable (mkPkgs nixpkgs-stable system);
            pkgs-unstable = import nixpkgs-unstable (mkPkgs nixpkgs-unstable system);
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
                    pkgs-stable = import nixpkgs-stable (mkPkgs nixpkgs-stable system);
                    pkgs-unstable = import nixpkgs-unstable (mkPkgs nixpkgs-unstable system);
                    inherit
                      inputs
                      nixpkgs
                      zjstatus
                      spicetify-nix
                      agenix
                      antigravity-nix
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
          pkgs = import nixpkgs {
            system = "x86_64-linux";
            config = {
              allowUnfree = true;
              permittedInsecurePackages = [
                "mdatp"
              ];
            };
          };
        in
        {
          # Custom applications
          claude-code = import ./home/development/claude-code {
            inherit (pkgs) lib buildNpmPackage fetchurl nodejs makeWrapper writeShellScriptBin;
          };
          codex-cli = pkgs.callPackage ./home/development/codex-cli {
            inherit (pkgs) nodejs_22;
          };
          gemini-cli = pkgs.callPackage ./pkgs/gemini-cli { };
          glim = pkgs.callPackage ./overlays/glim { };
          intune-portal = pkgs.callPackage ./pkgs/intune-portal { };
          kosli-cli = pkgs.callPackage ./pkgs/kosli-cli { };
          opencode = pkgs.callPackage ./home/development/opencode { };

          # Security tools
          mdatp = pkgs.callPackage ./pkgs/microsoft-defender-for-endpoint {
            inherit (pkgs) buildFHSEnv;
          };

          # Enterprise tools
          # NOTE: citrix-workspace is provided via overlay (overlays/citrix-workspace.nix)
          # It requires manual tarball download - see pkgs/citrix-workspace/fetch-citrix.sh

          # Icon themes
          neuwaita-icon-theme = pkgs.stdenvNoCC.mkDerivation {
            pname = "neuwaita-icon-theme";
            version = "unstable-2025-01-15";

            src = pkgs.fetchFromGitHub {
              owner = "RusticBard";
              repo = "Neuwaita";
              rev = "4c63e30493ab34558539104309282877ab767798";
              hash = "sha256-NL8/ceugdGNSMpa8G/a4Eolutf5BcN6PXiQ9qDmHM1U=";
            };

            dontBuild = true;
            dontConfigure = true;

            installPhase = ''
              runHook preInstall
              mkdir -p $out/share/icons/Neuwaita
              cp -r * $out/share/icons/Neuwaita/
              rm -rf $out/share/icons/Neuwaita/.git*
              runHook postInstall
            '';

            meta = with pkgs.lib; {
              description = "A different take on the Adwaita icon theme";
              homepage = "https://github.com/RusticBard/Neuwaita";
              license = licenses.gpl3Plus;
              platforms = platforms.linux;
            };
          };

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
