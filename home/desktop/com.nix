{pkgs, ...}: {
  home.packages = with pkgs; [
    # slack
    teams-for-linux
    thunderbird
    discord
    obsidian
    zathura
    dbeaver-bin
    postgresql
    caprine-bin
    element-desktop
    imagemagick
    fractal
    telegram-desktop
    whatsapp-for-linux
    ferdium
    zoom-us
    libcamera
  ];
}
