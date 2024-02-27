{ pkgs, pkgs-stable, ... }: {

home.packages = with pkgs; [
  
  mtr
  iperf3
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
  gnupg
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
  plasma-pass
  rofi-pass
  wofi-pass
  qjournalctl
  ];
}
