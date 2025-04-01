{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    nixpkgs,
    nixos-generators,
    ...
  } @ inputs: {
    nixosConfigurations = {
      m3-zelda = nixpkgs.lib.nixosSystem {
        modules = [
          ./configuration.nix
          inputs.disko.nixosModules.disko
        ];
        specialArgs = {
          isImageTarget = false;
        };
      };
    };
    packages.x86_64-linux = {
      iso = nixos-generators.nixosGenerate {
        system = "x86_64-linux";
        modules = [
          ./configuration.nix
        ];
        specialArgs = {
          isImageTarget = true;
        };
        format = "iso";
      };
      qcow = nixos-generators.nixosGenerate {
        system = "x86_64-linux";
        modules = [
          ./configuration.nix
        ];
        specialArgs = {
          isImageTarget = true;
        };
        format = "qcow";
      };
    };
  };
}
