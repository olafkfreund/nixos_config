{ pkgs, ... }: {
  home.packages = [
    (import ./nvidia-offload.nix { inherit pkgs; })
    (import ./screenshootin.nix { inherit pkgs; })
    (import ./info-tailscale.nix { inherit pkgs; })
    (import ./weather.nix { inherit pkgs; })
    (import ./screenshoot.nix { inherit pkgs; })
    (import ./hyprkeys.nix { inherit pkgs; })
    (import ./notify_count.nix { inherit pkgs; })
    (import ./search_web.nix { inherit pkgs; })
  ];
}
