{
  pkgs,
  pkgs-unstable,
  ...
}: {
  home.packages = [
    # slack
    pkgs.teams-for-linux
    pkgs.birdtray
    pkgs-unstable.thunderbird-latest
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
  xdg.mime.enable = true;
  xdg.mimeApps.enable = true;
  xdg.desktopEntries = {
    obsidian = {
      name = "Obsidian :)";
      # Fix for gpu issues
      exec = "obsidian --disable-gpu %u";
      categories = ["Office"];
      comment = "Knowledge base";
      icon = "obsidian";
      mimeType = ["x-scheme-handler/obsidian"];
      type = "Application";
    };
  };
}
