{
  pkgs,
  pkgs-stable,
  ...
}: {
  home.packages = [
    # slack
    pkgs-stable.teams-for-linux
    pkgs.thunderbird
    pkgs.discord
    # obsidian
    pkgs.dbeaver-bin
    pkgs.postgresql
    pkgs.caprine-bin
    pkgs.element-desktop
    pkgs.imagemagick
    pkgs.fractal
    pkgs.telegram-desktop
    pkgs.whatsapp-for-linux
    pkgs.ferdium
    pkgs.zoom-us
    pkgs.libcamera
  ];
}
