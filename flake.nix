{
  description = "Olaf's flake with Home Manager enabled";

  nixConfig = {
    # Primary caches
    substituters = [
      "https://cache.nixos.org/"
      "https://nix-community.cachix.org"
      "http://192.168.1.97:5000"
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
    nixvim = {
      url = "github:nix-community/nixvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Development and utilities
    sops-nix = {
      url = "github:mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Applications and specific tools
    claude-desktop = {
      url = "github:k3d3/claude-desktop-linux-flake";
      inputs.nixpkgs.follows = "nixpkgs-stable";
      inputs.flake-utils.follows = "flake-utils";
    };

    # Desktop environment
    hyprland = {
      url = "github:hyprwm/Hyprland";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Browser and media
    zen-browser.url = "github:0xc000022070/zen-browser-flake";
    spicetify-nix.url = "github:Gerg-L/spicetify-nix";

    # System utilities
    agenix.url = "github:ryantm/agenix";
    nix-snapd.url = "github:io12/nix-snapd";
    microvm.url = "github:astro/microvm.nix";

    # Additional tools
    nixcord.url = "github:kaylorben/nixcord";
    lan-mouse.url = "github:feschber/lan-mouse";
    bzmenu.url = "github:e-tho/bzmenu";
    iwmenu.url = "github:e-tho/iwmenu";
    walker.url = "github:abenz1267/walker";
    zjstatus.url = "github:dj95/zjstatus";
    ags.url = "github:Aylur/ags";

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

  outputs = {
    self,
    nixpkgs,
    nixpkgs-stable,
    nixpkgs-unstable,
    nur,
    nixai,
    agenix,
    razer-laptop-control,
    nixpkgs-f2k,
    nix-colors,
    nixcord,
    ags,
    nix-snapd,
    zen-browser,
    spicetify-nix,
    home-manager,
    stylix,
    nix-index-database,
    bzmenu,
    iwmenu,
    zjstatus,
    walker,
    hyprland,
    nixvim,
    ...
  } @ inputs: let
    # Import our enhanced custom library with modern host builders
    lib = import ./lib {
      inherit inputs nixpkgs;
      lib = nixpkgs.lib;
    };

    # Enhanced overlays with performance optimizations
    overlays = [
      # Custom packages overlay
      (final: prev: {
        customPkgs = import ./pkgs {
          pkgs = final;
        };
      })

      # Input-specific overlays
      (final: prev: {
        zjstatus = inputs.zjstatus.packages.${prev.system}.default;
        walker = inputs.walker.packages.${prev.system}.default;
        zen-browser = inputs.zen-browser.packages.${prev.system}.default;
      })

      # Performance overlays
      nur.overlay
    ];
  in {
    # Export our enhanced custom library for other flakes
    lib = lib;

    # Modern NixOS configurations using enhanced host builders
    nixosConfigurations = {
      # Primary Production Hosts
      p620 = lib.mkHost {
        hostname = "p620";
        hostType = "workstation";
        users = ["olafkfreund"];
        hardwareProfile = "amd-workstation";
        extraModules = [
          # Development environment
          ./modules/development/default.nix
          ./modules/containers/docker.nix
          ./modules/virtualization/qemu.nix
        ];
      };

      razer = lib.mkHost {
        hostname = "razer";
        hostType = "laptop";
        users = ["olafkfreund"];
        hardwareProfile = "intel-laptop";
        extraModules = [
          # Laptop-specific features
          ./modules/hardware/laptop.nix
          ./modules/hardware/power-management.nix
          razer-laptop-control.nixosModules.default
        ];
      };

      p510 = lib.mkHost {
        hostname = "p510";
        hostType = "workstation";
        users = ["olafkfreund"];
        hardwareProfile = "nvidia-gaming";
        extraModules = [
          # Gaming optimizations
          ./modules/gaming/steam.nix
          ./modules/gaming/performance.nix
          ./modules/virtualization/qemu.nix
        ];
      };

      dex5550 = lib.mkHost {
        hostname = "dex5550";
        hostType = "htpc";
        users = ["olafkfreund"];
        hardwareProfile = "htpc-intel";
        extraModules = [
          # HTPC-specific features
          ./modules/media/streaming.nix
        ];
      };

      # Additional Infrastructure Hosts
      hp = lib.mkHost {
        hostname = "hp";
        hostType = "workstation";
        users = ["olafkfreund"];
        hardwareProfile = "intel-workstation";
        extraModules = [
          ./modules/development/default.nix
        ];
      };

      lms = lib.mkHost {
        hostname = "lms";
        hostType = "server";
        users = ["olafkfreund"];
        hardwareProfile = "server-intel";
        extraModules = [
          # Server-specific modules
          ./modules/services/monitoring.nix
          ./modules/security/hardening.nix
        ];
      };

      pvm = lib.mkHost {
        hostname = "pvm";
        hostType = "workstation";
        users = ["olafkfreund"];
        hardwareProfile = "virtualization-host";
        extraModules = [
          # Virtualization host features
          ./modules/virtualization/qemu.nix
          ./modules/virtualization/kubernetes.nix
          ./modules/containers/docker.nix
        ];
      };
    };

    # Enhanced packages and applications
    packages.x86_64-linux = {
      # Development packages
      claude-code = import ./home/development/claude-code {
        inherit (nixpkgs.legacyPackages.x86_64-linux) lib buildNpmPackage fetchurl nodejs makeWrapper writeShellScriptBin;
      };
    };

    # Enhanced development shell with comprehensive tooling
    devShells.x86_64-linux = {
      default = nixpkgs.legacyPackages.x86_64-linux.mkShell {
        buildInputs = with nixpkgs.legacyPackages.x86_64-linux; [
          # Code formatting and linting
          alejandra # Nix formatter
          statix # Nix linter
          deadnix # Dead code finder
          nixpkgs-fmt # Alternative formatter

          # Development tools
          nix-tree # Dependency visualization
          nix-output-monitor # Better build output
          nixos-rebuild # System management
          just # Command runner

          # Documentation and validation
          mdbook # Documentation building
          shellcheck # Shell script linting

          # Git integration
          git
          gh # GitHub CLI

          # System tools
          htop
          neofetch
        ];

        shellHook = ''
          echo "🎯 NixOS Configuration Development Environment"
          echo "=============================================="
          echo ""
          echo "📋 Available Commands:"
          echo "  just --list          # Show all available commands"
          echo "  just validate        # Validate configuration"
          echo "  just format          # Format all Nix files"
          echo "  just lint            # Lint Nix code"
          echo "  just safety-check    # Comprehensive safety analysis"
          echo ""
          echo "🏠 Available Hosts:"
          echo "  Primary: p620 (AMD), razer (Intel laptop), p510 (NVIDIA), dex5550 (HTPC)"
          echo "  Additional: hp, lms (server), pvm (virtualization)"
          echo ""
          echo "🚀 Quick Start:"
          echo "  just dry-run HOSTNAME     # Preview changes"
          echo "  just safety-check HOSTNAME # Full analysis"
          echo "  just deploy-host HOSTNAME  # Apply configuration"
          echo ""
          echo "📚 Documentation: Check docs/ directory for guides"
        '';
      };

      # Specialized shells for different tasks
      docs = nixpkgs.legacyPackages.x86_64-linux.mkShell {
        buildInputs = with nixpkgs.legacyPackages.x86_64-linux; [
          mdbook
          graphviz
          plantuml
        ];
      };

      validation = nixpkgs.legacyPackages.x86_64-linux.mkShell {
        buildInputs = with nixpkgs.legacyPackages.x86_64-linux; [
          alejandra
          statix
          deadnix
          nixos-rebuild
        ];
      };
    };

    # Enhanced templates for creating new configurations
    templates = {
      minimal = {
        path = ./templates/minimal;
        description = "Minimal NixOS configuration with basic features";
        welcomeText = ''
          # Minimal NixOS Configuration Template

          This template provides a basic NixOS configuration suitable for:
          - Testing and development
          - Minimal server deployments
          - Learning NixOS fundamentals

          ## Quick Start:
          1. Edit flake.nix to add your hostname
          2. Configure variables.nix with your settings
          3. Run: nixos-rebuild switch --flake .#hostname
        '';
      };

      workstation = {
        path = ./templates/workstation;
        description = "Full-featured workstation configuration";
        welcomeText = ''
          # Workstation NixOS Configuration Template

          This template provides a comprehensive workstation setup with:
          - Desktop environment (Hyprland/Plasma)
          - Development tools and languages
          - Gaming and media support
          - Virtualization capabilities

          ## Features Included:
          - Modern window manager configurations
          - Complete development environment
          - Container and VM support
          - Gaming optimizations
          - Media production tools
        '';
      };

      server = {
        path = ./templates/server;
        description = "Hardened server configuration template";
        welcomeText = ''
          # Server NixOS Configuration Template

          This template provides a secure server configuration with:
          - Security hardening
          - Service monitoring
          - Container orchestration
          - Network optimization

          ## Security Features:
          - Minimal attack surface
          - Automated security updates
          - Intrusion detection
          - Secure defaults
        '';
      };
    };

    # Default template for quick initialization
    defaultTemplate = self.templates.minimal;

    # Additional outputs for advanced use cases
    homeConfigurations = let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
    in {
      # Standalone Home Manager configurations
      "olafkfreund@standalone" = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [
          ./Users/olafkfreund/home.nix
          inputs.nixvim.homeManagerModules.nixvim
          inputs.stylix.homeManagerModules.stylix
        ];
      };
    };

    # Formatter for the flake
    formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.alejandra;

    # Development overlays for other flakes to use
    overlays = {
      default = final: prev: {
        customPkgs = import ./pkgs {pkgs = final;};
      };

      performance = final: prev: {
        # Performance-optimized package variants
      };
    };

    # Apps for direct execution
    apps.x86_64-linux = {
      validate = {
        type = "app";
        program = "${nixpkgs.legacyPackages.x86_64-linux.writeShellScript "validate" ''
          exec ${./scripts/validate-config.sh}
        ''}";
      };

      deploy = {
        type = "app";
        program = "${nixpkgs.legacyPackages.x86_64-linux.writeShellScript "deploy" ''
          if [ $# -eq 0 ]; then
            echo "Usage: nix run .#deploy -- HOSTNAME"
            exit 1
          fi
          exec nixos-rebuild switch --flake .#$1
        ''}";
      };
    };
  };
}
