{
  description = "basic flake-utils";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  inputs.flake-utils.url = "github:numtide/flake-utils";
  inputs.nixos-generators = {
    url = "github:nix-community/nixos-generators";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, flake-utils, nixos-generators, ... }:
    (flake-utils.lib.eachDefaultSystem
      (system:
        let
          pkgs = import nixpkgs {
            inherit system;
          };


        in
        {

          packages.default = nixos-generators.nixosGenerate {
            system = "x86_64-linux";
            format = "raw";


            modules = [
              {
                boot.kernelParams = [ "console=tty0" ];
                users.users.alice = {
                  isNormalUser = true;
                  extraGroups = [ "wheel" ]; # Enable ‘sudo’ for the user.
                };
                # allow sudo without password for wheel
                security.sudo.wheelNeedsPassword = false;
              }
            ];
          };
        })
    );
}
