{pkgs, ...}: {
  home.packages = [
    (import ./emopicker.nix {inherit pkgs;})
    (import ./nvidia-offload.nix {inherit pkgs;})
    (import ./screenshootin.nix {inherit pkgs;})
    (import ./dunst.nix {inherit pkgs;})
    (import ./info-tailscale.nix {inherit pkgs;})
    (import ./choose_vpn_config.nix {inherit pkgs;})
    (import ./weather.nix {inherit pkgs;})
    (import ./monitor.nix {inherit pkgs;})
    (import ./update-checker.nix {inherit pkgs;})
    (import ./screenshoot.nix {inherit pkgs;})
    (import ./volume.nix {inherit pkgs;})
    (import ./powermenu.nix {inherit pkgs;})
  ];
}
