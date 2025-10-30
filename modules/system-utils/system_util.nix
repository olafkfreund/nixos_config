{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    # Core utilities (from consolidated sets)
    coreutils
    findutils
    gnugrep
    gnused
    gawk
    which
    tree
    file
    iproute2
    inetutils
    git
    curl
    wget
    unzip
    zip

    # Network utilities
    mtr
    iperf3
    dnsutils
    ldns
    nmap
    ipcalc

    # Development build tools
    pkg-config
    gtk4-layer-shell

    # System monitoring
    htop
    btop
    iotop

    # Additional system-specific packages
    bc
    zstd
    strace
    ltrace
    lsof
    sysstat
    lm_sensors
    ethtool
    pciutils
    usbutils
    ncurses
    psmisc
    w3m
    dmenu-wayland
    qtpass
    rofi-pass
    qjournalctl
    fwupd
    android-tools
    scrcpy
    libusb1
    acpi
    bluez-tools
    brightnessctl
    mpc
    alsa-utils
    # pamixer  # Temporarily disabled due to build failures with cxxopts/icu dependencies
    playerctl
    getent
    pavucontrol
    pulseaudio
    wireplumber
    networkmanager
    networkmanagerapplet
    networkmanager_dmenu
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
}
