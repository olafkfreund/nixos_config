{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    (import ./nix-index.nix { inherit pkgs; })
  ];
}
