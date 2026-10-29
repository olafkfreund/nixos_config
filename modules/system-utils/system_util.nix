{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    # Note: Core packages (coreutils, findutils, gnugrep, gnused, gawk, which, tree,
    # file, iproute2, inetutils, git, curl, wget, unzip, htop, btop, iotop, bc,
    # lsof, pciutils, usbutils, procps, psmisc, jq) are defined in
    # modules/nixos/packages/core.nix — do not duplicate here.

    # Archive tools
    zip
    zstd

    # Network utilities (beyond core)
    mtr
    iperf3
    ldns
    nmap
    ipcalc

    # Development build tools
    pkg-config
    gtk4-layer-shell

    # System diagnostics (beyond core)
    strace
    ltrace
    sysstat
    lm_sensors
    ethtool
    ncurses
    qjournalctl
    fwupd
    acpi

    # Android/USB tools
    android-tools
    scrcpy
    libusb1

    # Audio/Bluetooth
    bluez-tools
    brightnessctl
    mpc
    alsa-utils
    playerctl
    pavucontrol
    pulseaudio
    wireplumber

    # Network management
    networkmanager
    networkmanagerapplet
    networkmanager_dmenu

    # System tools
    getent
    keychain
    netscanner
    dbus
    libjpeg
    avahi
    libtool
    keylight-controller-mschneider82
    bottom
    sof-firmware
    openssl
    libsixel
    fd
    viddy
    curlie
    entr
    erdtree
    choose
    nitch
    pet
    rusti-cal
    rmpc
    gptfdisk
    icu
    spotdl
    termusic
    qFlipper
    chatterino2
    twitch-tui
    deploy-rs
  ];

  # pipewire-pulse is the server; stop libpulse clients autospawning a real pulseaudio
  environment.etc."pulse/client.conf".text = "autospawn = no\n";

  # A deploy that restarts the audio stack strands Chrome's mic (it never
  # reconnects to pipewire-pulse) and can drop the camera; a bump lands at next login.
  systemd.user.services = {
    pipewire.restartIfChanged = false;
    pipewire-pulse.restartIfChanged = false;
    wireplumber.restartIfChanged = false;
  };
}
