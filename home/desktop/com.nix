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
    # pkgs.discord
    # obsidian
    pkgs.dbeaver-bin
    pkgs.postgresql
    pkgs.caprine-bin
    pkgs.element-desktop
    pkgs.imagemagick
    pkgs.fractal
    # pkgs.telegram-desktop
    pkgs.whatsapp-for-linux
    pkgs.ferdium
    pkgs.zoom-us
    pkgs.libcamera
  ];
  xdg.mime.enable = true;
  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "text/html" = "google-chrome.desktop";
      "x-scheme-handler/http" = "google-chrome.desktop";
      "x-scheme-handler/https" = "google-chrome.desktop";
      "x-scheme-handler/about" = "google-chrome.desktop";
      "x-scheme-handler/unknown" = "google-chrome.desktop";
    };
  };
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
    google-chrome = {
      name = "google-chrome";
      exec = "google-chrome-stable %U";
      categories = ["Network"];
      comment = "Web Browser";
      icon = "google-chrome";
      mimeType = ["x-scheme-handler/http" "x-scheme-handler/https"];
      type = "Application";
    };
  };
}
