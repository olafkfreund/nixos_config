{ pkgs, ... }: {
  home.packages = with pkgs; [
    (import ./emopicker.nix { inherit pkgs; })
    (import ./nvidia-offload.nix { inherit pkgs; })
    (import ./screenshootin.nix { inherit pkgs; })
    (import ./list-hypr-bindings.nix { inherit pkgs; })
    (import ./wallsetter.nix { inherit pkgs; })
    (import ./start_wall.nix { inherit pkgs; })
    (import ./wallpaper_picker.nix { inherit pkgs; })
    (import ./wall.nix { inherit pkgs; })
    (import ./dunst.nix { inherit pkgs; })
    (import ./info-tailscale.nix { inherit pkgs; })
    (import ./choose_vpn_config.nix { inherit pkgs; })
    (import ./weather.nix { inherit pkgs; })
    (import ./album_art.nix { inherit pkgs; })
  ];
}
