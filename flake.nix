{
  description = "Olaf's flake with Home Manager enabled";

  nixConfig = {
    experimental-features = ["nix-command" "flakes"];
    substituters = [
      "https://cache.nixos.org/"
      "https://cuda-maintainers.cachix.org"
      "https://hyprland.cachix.org"
      "https://devenv.cachix.org"
      "https://cosmic.cachix.org/"
      "https://cache.saumon.network/proxmox-nixos"
    ];
    trusted-public-keys = [
      "cuda-maintainers.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUDZ9JyUG0VpVZa7CNfq5E="
      "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
      "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw="
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "cosmic.cachix.org-1:Dya9IyXD4xdBehWjrkPv6rtxpmMdRel02smYzA85dPE="
    ];
    extra-substituters = [
      # Nix community's cache server
      "https://nix-community.cachix.org"
    ];
    extra-trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };

  inputs = {
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    #Did not have time to clean everything up
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-24.11";
    #
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.11";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    nix-colors = {
      url = "github:misterio77/nix-colors";
    };

    home-manager = {
      url = "github:nix-community/home-manager/release-24.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # nixos-cosmic = {
    #   url = "github:lilyinstarlight/nixos-cosmic";
    #   inputs.nixpkgs.follows = "nixpkgs";
    # };

    microvm = {
      url = github:astro/microvm.nix;
      inputs.nixpkgs.follows = "nixpkgs";
    };

    spicetify-nix = {
      url = "github:Gerg-L/spicetify-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixpkgs-f2k = {
      url = "github:moni-dz/nixpkgs-f2k";
    };

    nur = {
      url = "github:nix-community/NUR";
    };

    nix-snapd = {
      url = "github:io12/nix-snapd";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    stylix = {
      url = "github:danth/stylix/release-24.11";
    };

    zen-browser.url = "github:0xc000022070/zen-browser-flake";

    razer-laptop-control = {
      url = "github:Razer-Linux/razer-laptop-control-no-dkms";
    };

    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    ags = {
      url = "github:Aylur/ags";
    };

    zjstatus = {
      url = "github:dj95/zjstatus";
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
    ags,
    nix-snapd,
    zen-browser,
    spicetify-nix,
    home-manager,
    stylix,
    nix-index-database,
    zjstatus,
    ...
  } @ inputs: let
    username = "olafkfreund";
    makeNixosSystem = host: {
      system = "x86_64-linux";
      specialArgs = {
        pkgs-stable = import nixpkgs-stable {
          system = "x86_64-linux";
          config.allowUnfree = true;
        };
        pkgs-unstable = import nixpkgs-unstable {
          system = "x86_64-linux";
          config.allowUnfree = true;
        };
        inherit inputs username host;
      };
      modules = [
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
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.backupFileExtension = "backup";
          home-manager.extraSpecialArgs = {
            pkgs-stable = import nixpkgs-stable {
              system = "x86_64-linux";
              config.allowUnfree = true;
            };
            pkgs-unstable = import nixpkgs-unstable {
              system = "x86_64-linux";
              config.allowUnfree = true;
            };
            inherit inputs nixpkgs zen-browser zjstatus spicetify-nix ags agenix razer-laptop-control stylix nix-index-database nixpkgs-f2k home-manager nixpkgs-stable nixpkgs-unstable nix-colors nix-snapd host;
          };
          home-manager.users.${username} = import ./Users/${username}/${host}_home.nix;
          home-manager.sharedModules = [
            {
              stylix.targets = {
                waybar.enable = false;
                yazi.enable = false;
                # vim.enable = false;
                vscode.enable = false;
                dunst.enable = false;
                rofi.enable = false;
                xresources.enable = false;
                neovim.enable = false;
                hyprpaper.enable = false;
                hyprland.enable = false;
                spicetify.enable = false;
                sway.enable = false;
                swaync.enable = false;
              };
            }
          ];
        }
      ];
    };
  in {
    nixosConfigurations = {
      razer = nixpkgs.lib.nixosSystem (makeNixosSystem "razer");
      # g3 = nixpkgs.lib.nixosSystem (makeNixosSystem "g3");
      lms = nixpkgs.lib.nixosSystem (makeNixosSystem "lms");
      dex5550 = nixpkgs.lib.nixosSystem (makeNixosSystem "dex5550");
      hp = nixpkgs.lib.nixosSystem (makeNixosSystem "hp");
      p510 = nixpkgs.lib.nixosSystem (makeNixosSystem "p510");
      p620 = nixpkgs.lib.nixosSystem (makeNixosSystem "p620");
    };
  };
}
