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
    # ./power/default.nix
    ./cron/cron.nix
    ./atuin/default.nix
    ./logind/default.nix
    ./ollama/default.nix
    ./sysprof/default.nix
    # ./libinput/default.nix
    #./snapd/default.nix
    ./mandb/default.nix
    ./appimage/default.nix
    ./dns/secure-dns.nix
    # ./dwm/default.nix

    # Network stability modules
    ./network-monitoring.nix
    ./network-stability.nix
    ./network-stability-service.nix
  ];
}
