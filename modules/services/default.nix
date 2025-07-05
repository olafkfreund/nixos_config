{...}: {
  imports = [
    ./mtr/mtr.nix
    ./print/default.nix
    ./flatpak/flatpak.nix
    ./xserver/xdg-portal.nix
    ./xserver/xdg.nix
    ./bluetooth/bluetooth.nix
    ./sound/sound.nix
    ./openssh/openssh.nix
    ./gnome/gnome-services.nix
    ./systemd/default.nix
    ./tailscale/default.nix
    ./system/default.nix
    ./cron/cron.nix
    ./atuin/default.nix
    ./logind/default.nix
    ./ollama/default.nix
    ./sysprof/default.nix
    ./mandb/default.nix
    ./appimage/default.nix
    ./dns/secure-dns.nix

    # Network stability modules (service merged into main module)
    ./network-monitoring.nix
    ./network-stability.nix
  ];
}
