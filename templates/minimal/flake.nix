{
  description = "Minimal NixOS Configuration Template";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    home-manager,
    ...
  } @ inputs: {
    nixosConfigurations = {
      # Replace 'hostname' with your actual hostname
      hostname = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";

        specialArgs = {inherit inputs;};

        modules = [
          ./configuration.nix

          # Home Manager
          home-manager.nixosModules.home-manager
          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              users.username = import ./home.nix; # Replace 'username'
            };
          }
        ];
      };
    };
  };
}
