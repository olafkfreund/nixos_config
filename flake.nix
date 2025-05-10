{
  description = "Olaf's flake with Home Manager enabled";

  nixConfig = {
    experimental-features = ["nix-command" "flakes"];

    # Primary caches
    substituters = [
      "https://cache.nixos.org/"
      "https://nix-community.cachix.org"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
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
    ];
    extra-trusted-public-keys = [
      "cuda-maintainers.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUDZ9JyUG0VpVZa7CNfq5E="
      "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
      "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw="
      "cosmic.cachix.org-1:Dya9IyXD4xdBehWjrkPv6rtxpmMdRel02smYzA85dPE="
      "walker-git.cachix.org-1:vmC0ocfPWh0S/vRAQGtChuiZBTAe4wiKDeyyXM0/7pM="
      "walker.cachix.org-1:fG8q+uAaMqhsMxWjwvk0IMb4mFPFLqHjuvfwQxE4oJM="
    ];
  };

  inputs = {
    # Core
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-24.11";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    flake-utils.url = "github:numtide/flake-utils";

    # Environment and theming
    home-manager.url = "github:nix-community/home-manager";
    nix-colors.url = "github:misterio77/nix-colors";
    stylix.url = "github:danth/stylix";

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
  };

  outputs = {
    self,
    nixpkgs,
    nixpkgs-stable,
    nixpkgs-unstable,
    nur,
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
    ...
  } @ inputs: let
    username = "olafkfreund";

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

    makeNixosSystem = host: {
      system = "x86_64-linux";
      specialArgs = {
        pkgs-stable = import nixpkgs-stable (mkPkgs nixpkgs-stable);
        pkgs-unstable = import nixpkgs-unstable (mkPkgs nixpkgs-unstable);
        inherit inputs username host;
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
                zen-browser
                zjstatus
                spicetify-nix
                ags
                agenix
                razer-laptop-control
                walker
                nixcord
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
                host
                ;
            };
            users.${username} = import ./Users/${username}/${host}_home.nix;
            sharedModules = [
              {
                stylix.targets = builtins.listToAttrs (map (name: {
                    inherit name;
                    value = {enable = false;};
                  }) [
                    "waybar"
                    "yazi"
                    "vscode"
                    "dunst"
                    "rofi"
                    "xresources"
                    "neovim"
                    "hyprpaper"
                    "hyprland"
                    "spicetify"
                    "sway"
                    "swaync"
                  ]);
              }
            ];
          };
        }
      ];
    };
  in {
    nixosConfigurations = {
      razer = nixpkgs.lib.nixosSystem (makeNixosSystem "razer");
      dex5550 = nixpkgs.lib.nixosSystem (makeNixosSystem "dex5550");
      hp = nixpkgs.lib.nixosSystem (makeNixosSystem "hp");
      p510 = nixpkgs.lib.nixosSystem (makeNixosSystem "p510");
      p620 = nixpkgs.lib.nixosSystem (makeNixosSystem "p620");
    };
  };
}
