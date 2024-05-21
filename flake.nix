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
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-23.11";
    
    nix-colors.url = "github:misterio77/nix-colors";
    
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    nixos-cosmic = {
      url = "github:lilyinstarlight/nixos-cosmic";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    
    spicetify-nix.url = "github:the-argus/spicetify-nix";

    hyprland.url = "git+https://github.com/hyprwm/Hyprland?submodules=1";
    #hyprland.url = "github:hyprwm/Hyprland";
    hyprland.inputs.nixpkgs.follows = "nixpkgs";

    hyprland-plugins = {
    url = "github:hyprwm/hyprland-plugins";
    inputs.hyprland.follows = "hyprland";
    };

    hyprpicker.url = "github:hyprwm/hyprpicker";
    hyprpicker.inputs.nixpkgs.follows = "nixpkgs";
    
    hyprland-contrib.url = "github:hyprwm/contrib";
    hyprland-contrib.inputs.nixpkgs.follows = "nixpkgs";
    
    agenix.url = "github:ryantm/agenix";
    agenix.inputs.nixpkgs.follows = "nixpkgs";
    
    nixpkgs-f2k.url = "github:moni-dz/nixpkgs-f2k";
    
    nur.url = "github:nix-community/NUR";

    hycov={
      url = "github:DreamMaoMao/hycov";
      inputs.hyprland.follows = "hyprland";
    };
    
    hyprlock = {
      url = "github:hyprwm/hyprlock";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    
    hypridle = {
      url = "github:hyprwm/hypridle";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    hyprspace = {
      url = "github:KZDKM/Hyprspace";
      inputs.hyprland.follows = "hyprland";
    };  
    stylix.url ="github:danth/stylix";

  };


  outputs = {
      self, 
      nixpkgs, 
      nixpkgs-stable, 
      hyprlock, 
      hyprspace, 
      hypridle, 
      hycov, 
      nur, 
      hyprland-plugins, 
      nixos-cosmic, 
      nixpkgs-f2k, 
      hyprland, 
      nix-colors, 
      spicetify-nix, 
      home-manager,
      stylix,
      ... }@inputs : 
    {
    nixosConfigurations = {
      razer = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = {
          inherit inputs;
          };
        modules = [
          ./configuration.nix
          nur.nixosModules.nur
          home-manager.nixosModules.home-manager
          nixos-cosmic.nixosModules.default
          inputs.nix-colors.homeManagerModules.default
          inputs.stylix.nixosModules.stylix
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
              inherit hyprland;
              inherit hycov;
              inherit stylix;
              inherit hyprspace;
              inherit nixpkgs-f2k;
              inherit home-manager;
              inherit nixpkgs-stable;
              inherit nix-colors;
              inherit self;
            };        
            home-manager.users.olafkfreund = import ./Users/olafkfreund/razer_home.nix;
            home-manager.sharedModules = [{
              stylix.targets.waybar.enable = false;
            }];
          }
        ];
      };
    };
  };
}
