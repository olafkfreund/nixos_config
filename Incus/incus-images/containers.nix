{ inputs, ...}: {
  nixosConfigurations = {
  container = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    modules = [
      "${inputs.nixpkgs}/nixos/modules/virtualisation/lxc-container.nix"
      (
        { pkgs, ... }:
        {
          environment.systemPackages = with pkgs; [ 
              vim
              neovim
              tmux
            ];
        }
      )
    ];
  };
 };
}
