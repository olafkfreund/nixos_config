{ pkgs, ... }: {

home.packages = with pkgs; [
  eww
  swww
  # waypaper
  # wl-clipboard
  cliphist
  grim
  slurp
  swayidle
  swaylock
  swaybg
  
  swappy
  hyprnome
  hyprshot
  hyprdim
  hyprlock
  hypridle
  hyprpaper
  emote
  # playerctl
  # brightnessctl
  # wl-clipboard
  # wlogout
  python311Packages.requests
  # mpc-cli
  # alsa-utils
  # pamixer
  betterlockscreen
  # ncdu
  # networkmanager
  # networkmanagerapplet
  # networkmanager_dmenu
  # wlroots
  # wlr-randr
  # pavucontrol
  # pulseaudio
  #acpi
  onlyoffice-bin_latest
  # bluez-tools
  # brightnessctl
  # p7zip # for reshade
  
  kdePackages.kdeconnect-kde
  kde-gruvbox
  
  # wireplumber
  # wdisplays
  watershot
  ];
}
