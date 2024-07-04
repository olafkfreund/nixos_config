{
  description = "Olaf's flake for work-lx with Home Manager enabled";

  nixConfig = {
    experimental-features = [ "nix-command" "flakes" ];
    substituters = [
      "https://cache.nixos.org/"
      "https://cuda-maintainers.cachix.org"
      "https://hyprland.cachix.org"
      "https://devenv.cachix.org"
      "https://cosmic.cachix.org/"
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
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-24.05";

    nix-colors ={ 
      url = "github:misterio77/nix-colors";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
     url = "github:mic92/sops-nix";
     inputs.nixpkgs.follows ="nixpkgs";
    };


    nixos-cosmic = {
      url = "github:lilyinstarlight/nixos-cosmic";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    spicetify-nix = {
      url = "github:the-argus/spicetify-nix";
    };

    # hyprland = {
    #   url = "git+https://github.com/hyprwm/Hyprland?submodules=1";
    #   #hyprland.url = "git+https://github.com/hyprwm/Hyprland?submodules=1&ref=refs/tags/v0.41.0";
    #   #hyprland.url = "github:hyprwm/Hyprland";
    # };

    # hyprland-plugins = {
    #   url = "github:hyprwm/hyprland-plugins";
    #   inputs.hyprland.follows = "hyprland";
    # };


    #   inputs.hyprland.follows = "hyprland";
    # };

    nix-ld = {
      url = "github:Mic92/nix-ld";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # hyprland-contrib = {
    #   url = "github:hyprwm/contrib";
    #   inputs.hyprland.follows = "hyprland";
    # };

    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixpkgs-f2k = {
      url = "github:moni-dz/nixpkgs-f2k";
    };

    nur ={
      url = "github:nix-community/NUR";
    };

    nix-snapd = {
      url = "github:io12/nix-snapd";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    
    # hyprspace = {
    #   url = "github:KZDKM/Hyprspace";
    #   inputs.hyprland.follows = "hyprland";
    # };

    stylix = {
      url = "github:danth/stylix";
    };

    razer-laptop-control = {
      url = "github:Razer-Linux/razer-laptop-control-no-dkms";
    };

    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    browser-previews = {
      url = "github:nix-community/browser-previews";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    ags ={
      url = "github:Aylur/ags";
    };

  };

  outputs =
    { self
    , nixpkgs
    , nixpkgs-stable
    , nur
    , nixos-cosmic
    , razer-laptop-control
    , nixpkgs-f2k
    , nix-colors
    , ags
    , browser-previews
    , nix-ld
    , nix-snapd
    , spicetify-nix
    , home-manager
    , stylix
    , nix-index-database
    , ...
    } @ inputs: {
      nixosConfigurations = {
        razer = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = {
            inherit inputs;
          };
          modules = [
            ./hosts/razer/configuration.nix
            nur.nixosModules.nur
            home-manager.nixosModules.home-manager
            nixos-cosmic.nixosModules.default
            inputs.nix-colors.homeManagerModules.default
            inputs.stylix.nixosModules.stylix
            inputs.nix-ld.nixosModules.nix-ld
            inputs.nix-snapd.nixosModules.default
            inputs.razer-laptop-control.nixosModules.default
            nix-index-database.nixosModules.nix-index
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.backupFileExtension = "backup";
              home-manager.extraSpecialArgs = {
                pkgs-stable = import nixpkgs-stable {
                  system = "x86_64-linux";
                  config.allowUnfree = true;
                };
                inherit inputs;
                inherit nixpkgs;
                inherit spicetify-nix;
                inherit ags;
                inherit nix-ld;
                inherit razer-laptop-control;
                inherit stylix;
                inherit nix-index-database;
                inherit nixpkgs-f2k;
                inherit home-manager;
                inherit browser-previews;
                inherit nixpkgs-stable;
                inherit nix-colors;
                inherit nix-snapd;
                inherit self;
              };
              home-manager.users.olafkfreund = import ./Users/olafkfreund/razer_home.nix;
              home-manager.sharedModules = [
                {
                  stylix.targets.waybar.enable = false;
                  stylix.targets.yazi.enable = false;
                  stylix.targets.vim.enable = false;
                  stylix.targets.vscode.enable = false;
                  stylix.targets.dunst.enable = false;

                }
              ];
            }
          ];
        };
      };
    };
}
