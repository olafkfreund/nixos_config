{ pkgs, ... }: {

  home.packages = with pkgs; [
    (import ./emopicker.nix { inherit pkgs; })
    #(import ./themechange.nix { inherit pkgs;})
    (import ./theme-selector.nix { inherit pkgs; })
    (import ./nvidia-offload.nix { inherit pkgs; })
    (import ./screenshootin.nix { inherit pkgs; })
    (import ./list-hypr-bindings.nix { inherit pkgs; })
  ];
}
