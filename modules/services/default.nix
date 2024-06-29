{ ... }: {
  imports = [
    ./mtr/mtr.nix
    ./printing/print.nix
    ./flatpak/flatpak.nix
    ./xserver/xdg-portal.nix
    ./xserver/xdg.nix
    ./xserver/xserver.nix
    ./bluetooth/bluetooth.nix
    ./sound/sound.nix
    ./openssh/openssh.nix
    ./gnome/gnome-services.nix
    ./systemd/default.nix
    ./tailscale/default.nix
    ./system/default.nix
    ./power/default.nix
    ./cron/cron.nix
    ./atuin/default.nix
    ./logind/default.nix
    ./auto-cpufreq/default.nix
    ./greetd/greetd.nix
    ./ollama/default.nix
    ./sysprof/default.nix
    ./libinput/default.nix
    ./snapd/default.nix
    ./mandb/default.nix
    ./razer-laptop-control/default.nix
  ];


}
