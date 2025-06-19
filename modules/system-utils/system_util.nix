{
  pkgs,
  pkgs-stable,
  inputs,
  ...
}: {
  environment.systemPackages = with pkgs; [
    mtr
    iperf3
    bc
    dnsutils
    ldns
    nmap
    ipcalc
    file
    which
    tree
    gnused
    gawk
    zstd
    btop
    iotop
    iftop
    strace
    ltrace
    lsof
    sysstat
    lm_sensors
    ethtool
    pciutils
    usbutils
    ncurses
    coreutils
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
    mpc-cli
    alsa-utils
    pamixer
    playerctl
    getent
    brightnessctl
    pavucontrol
    pulseaudio
    ncdu
    wireplumber
    networkmanager
    networkmanagerapplet
    networkmanager_dmenu
    keychain
    netscanner
    # gawk
    # cups
    # ghostscript
    dbus
    libjpeg
    avahi
    # sane-airscan
    # simple-scan
    libtool
    # system-config-printer
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
    # tailspin
    nitch
    pet
    entr
    rusti-cal
    rmpc
    mpd
    mpdris2
    mpd-notification
    gptfdisk
    icu
    spotdl
    termusic
    # tauon
    qflipper
    chatterino2
    twitch-tui
    deploy-rs
    mkchromecast
    #dfu-utils
    inputs.iwmenu.packages.${pkgs.system}.default
    inputs.bzmenu.packages.${pkgs.system}.default
  ];
}
