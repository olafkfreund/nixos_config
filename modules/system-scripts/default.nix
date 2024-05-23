{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    (import ./nix-index.nix { inherit pkgs; })
    (import ./fzf-preview.nix { inherit pkgs; })
  ];
}
