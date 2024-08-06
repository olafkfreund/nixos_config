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

    nix-colors = {
      url = "github:misterio77/nix-colors";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-cosmic = {
      url = "github:lilyinstarlight/nixos-cosmic";
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
    nur,
    nixos-cosmic,
    razer-laptop-control,
    nixpkgs-f2k,
    nix-colors,
    ags,
    browser-previews,
    nix-snapd,
    spicetify-nix,
    home-manager,
    stylix,
    nix-index-database,
    zjstatus,
    ...
  } @ inputs: 
  let
    username = "olafkfreund";
  in  
    {
    nixosConfigurations = {
      razer = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = 
            let
              host = "razer";
            in 
         {
          inherit inputs;
          inherit username;  
          inherit host;
        };
        modules = [
          ./hosts/razer/configuration.nix
          nur.nixosModules.nur
          home-manager.nixosModules.home-manager
          nixos-cosmic.nixosModules.default
          inputs.nix-colors.homeManagerModules.default
          inputs.stylix.nixosModules.stylix
          inputs.nix-snapd.nixosModules.default
          inputs.razer-laptop-control.nixosModules.default
          nix-index-database.nixosModules.nix-index
          ./home/shell/zellij/zjstatus.nix
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.backupFileExtension = "backup";
            home-manager.extraSpecialArgs = 
                let
                  host = "razer";
                in
             {
              pkgs-stable = import nixpkgs-stable {
                system = "x86_64-linux";
                config.allowUnfree = true;
              };
              inherit host;
              inherit zjstatus;
              inherit inputs;
              inherit nixpkgs;
              inherit spicetify-nix;
              inherit ags;
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
            home-manager.users.${username} = import ./Users/${username}/razer_home.nix;
            home-manager.sharedModules = [
              {
                stylix.targets.waybar.enable = false;
                stylix.targets.yazi.enable = false;
                stylix.targets.vim.enable = false;
                stylix.targets.vscode.enable = false;
                stylix.targets.dunst.enable = false;
                stylix.targets.rofi.enable = false;
                stylix.targets.xresources.enable = false;
              }
            ];
          }
        ];
      };
      g3 = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = 
            let
              host = "g3";
            in {
          inherit inputs;
          inherit username;
          inherit host;
        };
        modules = [
          ./hosts/g3/configuration.nix
          ./home/shell/zellij/zjstatus.nix
          nur.nixosModules.nur
          home-manager.nixosModules.home-manager
          inputs.nix-colors.homeManagerModules.default
          inputs.stylix.nixosModules.stylix
          inputs.nix-snapd.nixosModules.default
          nix-index-database.nixosModules.nix-index
          ./home/shell/zellij/zjstatus.nix
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.backupFileExtension = "backup";
            home-manager.extraSpecialArgs = 
                let
                  host = "g3";
                in {
              pkgs-stable = import nixpkgs-stable {
                system = "x86_64-linux";
                config.allowUnfree = true;
              };
              inherit inputs;
              inherit nixpkgs;
              inherit zjstatus;
              inherit stylix;
              inherit nix-index-database;
              inherit nixpkgs-f2k;
              inherit home-manager;
              inherit nixpkgs-stable;
              inherit nix-colors;
              inherit nix-snapd;
              inherit self;
              inherit host;
            };
            home-manager.users.${username} = import ./Users/${username}/g3_home.nix;
            home-manager.sharedModules = [
              {
                stylix.targets.vim.enable = false;
              }
            ];
          }
        ];
      };
      lms = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = 
            let
              host = "lms";
            in {
          inherit inputs;
          inherit username;
          inherit host;    
        };
        modules = [
          ./hosts/lms/configuration.nix
          nur.nixosModules.nur
          home-manager.nixosModules.home-manager
          inputs.nix-colors.homeManagerModules.default
          inputs.stylix.nixosModules.stylix
          nixos-cosmic.nixosModules.default
          inputs.nix-snapd.nixosModules.default
          nix-index-database.nixosModules.nix-index
          ./home/shell/zellij/zjstatus.nix
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.backupFileExtension = "backup";
            home-manager.extraSpecialArgs = 
                let
                  host = "lms";
                in {
              pkgs-stable = import nixpkgs-stable {
                system = "x86_64-linux";
                config.allowUnfree = true;
              };
              inherit inputs;
              inherit nixpkgs;
              inherit zjstatus;
              inherit spicetify-nix;
              inherit ags;
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
              inherit host;
            };
            home-manager.users.${username} = import ./Users/${username}/lms_home.nix;
            home-manager.sharedModules = [
              {
                stylix.targets.waybar.enable = false;
                stylix.targets.yazi.enable = false;
                stylix.targets.vim.enable = false;
                stylix.targets.vscode.enable = false;
                stylix.targets.dunst.enable = false;
                stylix.targets.rofi.enable = false;
              }
            ];
          }
        ];
      };    
      dex5550 = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = 
            let
              host = "dex5550";
            in {
          inherit inputs;
          inherit username;
          inherit host;    
        };
        modules = [
          ./hosts/dex5550/configuration.nix
          ./home/shell/zellij/zjstatus.nix
          nur.nixosModules.nur
          home-manager.nixosModules.home-manager
          nixos-cosmic.nixosModules.default
          inputs.nix-colors.homeManagerModules.default
          inputs.stylix.nixosModules.stylix
          inputs.nix-snapd.nixosModules.default
          nix-index-database.nixosModules.nix-index
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.backupFileExtension = "backup";
            home-manager.extraSpecialArgs = 
                let
                  host = "dex5550";
                in {
              pkgs-stable = import nixpkgs-stable {
                system = "x86_64-linux";
                config.allowUnfree = true;
              };
              inherit inputs;
              inherit nixpkgs;
              inherit zjstatus;
              inherit spicetify-nix;
              inherit ags;
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
              inherit host;
            };
            home-manager.users.${username} = import ./Users/${username}/dex5550_home.nix;
            home-manager.sharedModules = [
              {
                stylix.targets.waybar.enable = false;
                stylix.targets.yazi.enable = false;
                stylix.targets.vim.enable = false;
                stylix.targets.vscode.enable = false;
                stylix.targets.dunst.enable = false;
                stylix.targets.rofi.enable = false;
              }
            ];
          }
        ];
      };    
      hp = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = 
            let
              host = "hp";
            in {
          inherit inputs;
          inherit username;
          inherit host;
        };
        modules = [
          ./hosts/hp/configuration.nix
          ./home/shell/zellij/zjstatus.nix
          nur.nixosModules.nur
          home-manager.nixosModules.home-manager
          inputs.nix-colors.homeManagerModules.default
          inputs.stylix.nixosModules.stylix
          inputs.nix-snapd.nixosModules.default
          nix-index-database.nixosModules.nix-index
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.backupFileExtension = "backup";
            home-manager.extraSpecialArgs = 
                let
                  host = "hp";
                in {
              pkgs-stable = import nixpkgs-stable {
                system = "x86_64-linux";
                config.allowUnfree = true;
              };
              inherit inputs;
              inherit nixpkgs;
              inherit zjstatus;
              inherit spicetify-nix;
              inherit ags;
              inherit stylix;
              inherit nix-index-database;
              inherit nixpkgs-f2k;
              inherit home-manager;
              inherit browser-previews;
              inherit nixpkgs-stable;
              inherit nix-colors;
              inherit nix-snapd;
              inherit self;
              inherit host;    
            };
            home-manager.users.${username} = import ./Users/${username}/hp_home.nix;
            home-manager.sharedModules = [
              {
                stylix.targets.waybar.enable = false;
                stylix.targets.yazi.enable = false;
                stylix.targets.vscode.enable = false;
                stylix.targets.dunst.enable = false;
                stylix.targets.rofi.enable = false;
                stylix.targets.vim.enable = false;
              }
            ];
          }
        ];
      };
    };
  };
}
