{
  description = "Olaf's flake for work-lx with Home Manager enabled";

  nixConfig = {
    experimental-features = [ "nix-command" "flakes" ];
    substituters = [
      "https://cache.nixos.org/"
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
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    nix-colors.url = "github:misterio77/nix-colors";
    spicetify-nix.url = "github:the-argus/spicetify-nix";
    hyprland.url = "github:hyprwm/Hyprland";
    hyprpicker.url = "github:hyprwm/hyprpicker";
    hypr-contrib.url = "github:hyprwm/contrib";
    nixpkgs-f2k.url = "github:moni-dz/nixpkgs-f2k";
    nur.url = "github:nix-community/NUR";
    kde2nix.url = "github:nix-community/kde2nix";
  };


  outputs = inputs@{
    self, nixpkgs, nixpkgs-stable, nixpkgs-f2k, nur, kde2nix, hyprland, spicetify-nix, home-manager, ... }: 
    {
    nixosConfigurations = {
      razer = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = {
          inherit inputs;
          };
        modules = [
          ./configuration.nix
          kde2nix.nixosModules.plasma6
          nur.nixosModules.nur
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = {
              pkgs-stable = import nixpkgs-stable {
              system = "x86_64-linux";
              config.allowUnfree = true;
              };
              inherit inputs;
              inherit nixpkgs;
              inherit spicetify-nix;
              inherit hyprland;
              inherit home-manager;
              inherit nixpkgs-stable;
              inherit self;
              inherit nixpkgs-f2k;
            };        
            home-manager.users.olafkfreund = import ./Users/olafkfreund/razer_home.nix;
          }
        ];
      };
      work-lx = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = {
          inherit inputs;
        };
        modules = [
          ./configuration.nix
          nur.nixosModules.nur
          kde2nix.nixosModules.plasma6
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = {
              pkgs-stable = import nixpkgs-stable {
              system = "x86_64-linux";
              config.allowUnfree = true;
              };
              inherit inputs;
              inherit nixpkgs;
              inherit spicetify-nix;
              inherit hyprland;
              inherit home-manager;
              inherit nixpkgs-stable;
              inherit self;
              inherit nixpkgs-f2k;
            };        
            home-manager.users.olafkfreund = import ./Users/olafkfreund/work-lx_home.nix;
          }
        ];
      };
    };
  };
}
