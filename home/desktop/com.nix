{ pkgs, ... }: {
  home.packages = [
    # slack
    pkgs.teams-for-linux
    pkgs.birdtray
    # pkgs.discord
    # obsidian
    pkgs.dbeaver-bin
    pkgs.postgresql
    pkgs.caprine-bin
    # pkgs.element-desktop  # Disabled: depends on insecure jitsi-meet package (CVE-2024-45191, CVE-2024-45192, CVE-2024-45193)
    pkgs.imagemagick
    # pkgs.fractal
    pkgs.vesktop # Re-enabled: upstream build fixed in nixpkgs
    # pkgs.telegram-desktop
    pkgs.wasistlos
    # pkgs.ferdium  # Removed: no longer needed
    pkgs.zoom-us
    pkgs.libcamera
    pkgs.nchat
  ];
  xdg = {
    mime.enable = true;
    mimeApps = {
      enable = true;
      defaultApplications = {
        "text/html" = "firefox.desktop";
        "x-scheme-handler/http" = "firefox.desktop";
        "x-scheme-handler/https" = "firefox.desktop";
        "x-scheme-handler/about" = "firefox.desktop";
        "x-scheme-handler/unknown" = "firefox.desktop";
      };
    };
    desktopEntries = {
      obsidian = {
        name = "Obsidian :)";
        # Fix for gpu issues
        exec = "obsidian --disable-gpu %u";
        categories = [ "Office" ];
        comment = "Knowledge base";
        icon = "obsidian";
        mimeType = [ "x-scheme-handler/obsidian" ];
        type = "Application";
      };
      firefox = {
        name = "Firefox";
        exec = "firefox %U";
        categories = [ "Network" ];
        comment = "Web Browser";
        icon = "firefox";
        mimeType = [ "text/html" "x-scheme-handler/http" "x-scheme-handler/https" ];
        type = "Application";
      };

      google-chrome = {
        name = "google-chrome";
        exec = "google-chrome-stable %U";
        categories = [ "Network" ];
        comment = "Web Browser";
        icon = "google-chrome";
        mimeType = [ "x-scheme-handler/http" "x-scheme-handler/https" ];
        type = "Application";
      };
    };
  };
}
