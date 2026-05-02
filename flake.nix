{
  description = "Olaf's flake with Home Manager enabled";

  nixConfig = {
    # Primary caches
    substituters = [
      "https://cache.nixos.org/"
      "https://nix-community.cachix.org/"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];

    # Development and specific package caches
    extra-substituters = [
      "https://cuda-maintainers.cachix.org/"
      "https://hyprland.cachix.org/"
      "https://devenv.cachix.org/"
      "https://cosmic.cachix.org/"
    ];
    extra-trusted-public-keys = [
      "cuda-maintainers.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUDZ9JyUG0VpVZa7CNfq5E="
      "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
      "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw="
      "cosmic.cachix.org-1:Dya9IyXD4xdBehWjrkPv6rtxpmMdRel02smYzA85dPE="
    ];
  };

  inputs = {
    # Core
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-25.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    flake-utils.url = "github:numtide/flake-utils";

    # MCP servers
    mcp-nixos.url = "github:utensils/mcp-nixos";

    # Environment and theming
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    stylix = {
      url = "github:danth/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

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

    # Secure Boot — v0.4.1 broke against current nixpkgs (rust-1.78 toolchain
    # fetch failure). v1.0.0 (released 2025-12-10) is the latest stable.
    lanzaboote = {
      url = "github:nix-community/lanzaboote/v1.0.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Additional tools
    lan-mouse.url = "github:feschber/lan-mouse";
    zjstatus.url = "github:dj95/zjstatus";
    # = tag v2.0.5+claude1.5354.0 (2026-04-30). Wrapper at v2.0.5 includes
    # upstream's own CRLF-strip fix for cowork-plugin-shim.sh (PRs #499,
    # #505) — our overlay's postInstall workaround is now unneeded; the
    # overlay below simplifies to a direct FHS pass-through.
    # claude binary at 1.5354.0.
    # Bump via /update-claude-code.
    claude-desktop-linux.url = "github:aaddrick/claude-desktop-debian/dc762a35a02782415fcaa84f0d7ed9d2a6064215";

    # Terminal YouTube browser
    yt-x = {
      url = "github:Benexl/yt-x";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # COSMIC Connect - KDE Connect alternative for COSMIC Desktop
    cosmic-ext-connect = {
      url = "github:olafkfreund/cosmic-ext-connect-desktop-app";
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

    # Google Antigravity package
    antigravity-nix = {
      url = "github:jacopone/antigravity-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # COSMIC Desktop applets
    cosmic-music-player = {
      url = "github:olafkfreund/cosmic-applet-music-player";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    cosmic-applet-spotify = {
      url = "github:nomoth/cosmic-applet-spotify";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # COSMIC Radio Applet - Internet radio player for COSMIC Desktop
    cosmic-ext-radio-applet = {
      url = "github:olafkfreund/cosmic-ext-radio-applet";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # COSMIC Web Apps - Web application manager for COSMIC Desktop
    cosmic-ext-web-apps = {
      url = "github:olafkfreund/cosmic-ext-web-apps";
      inputs.nixpkgs.follows = "nixpkgs";
    };

  };

  outputs =
    { nixpkgs
    , nixpkgs-stable
    , nixpkgs-unstable
    , nur
    , agenix
    , spicetify-nix
    , home-manager
    , nix-index-database
    , zjstatus
    , antigravity-nix
    , mcp-nixos
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
        razer = [ "olafkfreund" ];
        p510 = [ "olafkfreund" ];
      };

      # Live image builder
      liveImages = import ./lib/live-images.nix {
        inherit nixpkgs inputs hostUsers;
      };

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
        localSystem = system; # Modern replacement for deprecated 'system' parameter
        config = {
          allowUnfree = true;
          # allowInsecure = false; # REMOVED for security - using targeted permissions
        };
      };

      overlays = import ./overlays { inherit inputs; };

      makeNixosSystem = host:
        let
          primaryUser = getPrimaryUser host;
          allUsers = getHostUsers host;
          # Stylix theming module - re-enabled after upstream cache fix
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
            # MCP servers from flakes
            mcp-nixos-pkg = mcp-nixos.packages.${system}.default;
          };
          modules =
            [
              { nixpkgs.overlays = overlays; }
              ./hosts/${host}/configuration.nix
              nur.modules.nixos.default
              home-manager.nixosModules.home-manager
              inputs.nix-snapd.nixosModules.default
              inputs.agenix.nixosModules.default
              inputs.lanzaboote.nixosModules.lanzaboote
              nix-index-database.nixosModules.nix-index
              inputs.cosmic-ext-connect.nixosModules.default
              # cosmic-ext-applet-radio: local module workaround for upstream mkPackageOption 'description' arg bug
              ./modules/services/cosmic-ext-radio-applet
              ./home/shell/zellij/zjstatus.nix
            ]
            ++ stylixModule
            ++ [
              {
                home-manager = {
                  useGlobalPkgs = true;
                  useUserPackages = true;
                  # Use backup command to move files to timestamped directory
                  # This prevents backup file collisions by using unique directories
                  backupCommand = ''
                    backup_dir = "$HOME/.hm-backups/$(date +%Y-%m-%d-%H%M%S)"
                      mkdir - p "$(dirname "$backup_dir/$1 ")"
                      mv "$1" "$backup_dir/$1"
                  '';
                  # Shared modules for all users
                  sharedModules = [
                    {
                      stylix.targets.firefox.enable = false;
                    }
                  ];
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
          claude-code-native = pkgs.callPackage ./pkgs/claude-code-native { };
          codex-cli = pkgs.callPackage ./home/development/codex-cli {
            inherit (pkgs) nodejs_24;
          };
          glim = pkgs.callPackage ./overlays/glim { };
          intune-portal = pkgs.callPackage ./pkgs/intune-portal { };
          kosli-cli = pkgs.callPackage ./pkgs/kosli-cli { };
          opencode = pkgs.callPackage ./home/development/opencode { };
          aurynk = pkgs.callPackage ./pkgs/aurynk { };
          # add-skill = pkgs.callPackage ./pkgs/add-skill { };

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
              runHook
              preInstall
              mkdir - p $out/share/icons/Neuwaita
              cp - r * $out/share/icons/Neuwaita/
              rm - rf $out/share/icons/Neuwaita/.git *
              runHook postInstall
            '';

            meta = with pkgs.lib; {
              description = "A different take on the Adwaita icon theme";
              homepage = "https://github.com/RusticBard/Neuwaita";
              license = licenses.gpl3Plus;
              platforms = platforms.linux;
            };
          };

          # Live ISO images
          live-iso-razer = liveImages.liveImages.live-iso-razer.config.system.build.isoImage;

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
            program = "${appPkgs.dev-utils} /bin/nixos-dev-utils";
          };
        };

      # Code formatter for consistent formatting
      formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixpkgs-fmt;
    };
}

