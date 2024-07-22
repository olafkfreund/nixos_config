{ inputs, ...}: {
  nixosConfigurations = {
  container = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    modules = [
      "${inputs.nixpkgs}/nixos/modules/virtualisation/lxc-container.nix"
      (
        { pkgs, ... }:
        {
          environment.systemPackages = [ pkgs.vim ];
        }
      )
    ];
  };

  vm = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    modules = [
      "${inputs.nixpkgs}/nixos/modules/virtualisation/lxd-virtual-machine.nix"
      (
        { pkgs, ... }:
        {
          environment.systemPackages = [ pkgs.vim ];
        }
      )
    ];
  };
 };
}
