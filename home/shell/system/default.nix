{ pkgs, ... }: {

home.packages = with pkgs; [
  
  jq
  mtr
  file
  which
  tree
  gnused
  gnutar
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
  less
  ncurses
  coreutils
  psmisc
  pass
  ];
}
