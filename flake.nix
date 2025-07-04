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
    spicetify-nix.url = "github:Gerg-L/spicetify-nix";

    # System utilities
    agenix.url = "github:ryantm/agenix";
    nix-snapd.url = "github:io12/nix-snapd";
    microvm.url = "github:astro/microvm.nix";

    # Additional tools
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
    ags,
    nix-snapd,
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
    # Define users per host
    hostUsers = {
      p620 = ["olafkfreund"];
      samsung = ["olafkfreund"];
      razer = ["olafkfreund"];
      p510 = ["olafkfreund"];
      dex5550 = ["olafkfreund"];
    };

    # Get primary user (first in the list) for backward compatibility
    getPrimaryUser = host: builtins.head (hostUsers.${host} or ["olafkfreund"]);

    # Get all users for a host
    getHostUsers = host: hostUsers.${host} or ["olafkfreund"];

    # Helper function for package imports
    mkPkgs = pkgs: {
      system = "x86_64-linux";
      config.allowUnfree = true;
      config.allowInsecure = true;
    };

    # Import custom packages
    overlays = [
      (final: prev: {
        customPkgs = import ./pkgs {
          pkgs = final;
        };
      })
      (final: prev: {
        zjstatus = inputs.zjstatus.packages.${prev.system}.default;
      })
    ];

    makeNixosSystem = host: let
      primaryUser = getPrimaryUser host;
      allUsers = getHostUsers host;
    in {
      system = "x86_64-linux";
      specialArgs = {
        pkgs-stable = import nixpkgs-stable (mkPkgs nixpkgs-stable);
        pkgs-unstable = import nixpkgs-unstable (mkPkgs nixpkgs-unstable);
        inherit inputs host;
        username = primaryUser; # Primary user for backward compatibility
        hostUsers = allUsers; # All users for this host
      };
      modules = [
        {nixpkgs.overlays = overlays;}
        ./hosts/${host}/configuration.nix
        nur.modules.nixos.default
        home-manager.nixosModules.home-manager
        inputs.nix-colors.homeManagerModules.default
        inputs.stylix.nixosModules.stylix
        inputs.nix-snapd.nixosModules.default
        inputs.agenix.nixosModules.default
        nix-index-database.nixosModules.nix-index
        ./home/shell/zellij/zjstatus.nix
        inputs.nixvim.nixosModules.nixvim
        nixai.nixosModules.default
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
                ags
                agenix
                razer-laptop-control
                walker
                stylix
                nix-index-database
                nixpkgs-f2k
                bzmenu
                iwmenu
                home-manager
                nixpkgs-stable
                nixpkgs-unstable
                nix-colors
                nix-snapd
                nixvim
                host
                ;
              username = primaryUser;
              hostUsers = allUsers;
            };

            # Configure home-manager for all users on this host
            users = builtins.listToAttrs (map (user: {
                name = user;
                value = import ./Users/${user}/${host}_home.nix;
              })
              allUsers);
            sharedModules = [
              inputs.nixvim.homeManagerModules.nixvim
              nixai.homeManagerModules.default
            ];
          };
        }
      ];
    };
  in {
    nixosConfigurations = {
      razer = nixpkgs.lib.nixosSystem (makeNixosSystem "razer");
      dex5550 = nixpkgs.lib.nixosSystem (makeNixosSystem "dex5550");
      # hp = nixpkgs.lib.nixosSystem (makeNixosSystem "hp");
      p510 = nixpkgs.lib.nixosSystem (makeNixosSystem "p510");
      p620 = nixpkgs.lib.nixosSystem (makeNixosSystem "p620");
      samsung = nixpkgs.lib.nixosSystem (makeNixosSystem "samsung");
    };

    packages.x86_64-linux = {
      claude-code = import ./home/development/claude-code {
        inherit (nixpkgs.legacyPackages.x86_64-linux) lib buildNpmPackage fetchurl nodejs makeWrapper writeShellScriptBin;
      };
      gemini-cli = nixpkgs.legacyPackages.x86_64-linux.callPackage ./pkgs/gemini-cli {};
    };
  };
}
