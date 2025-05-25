{pkgs, ...}: {
  imports = [
    ../common/base-home.nix
    # Add htpcuser-specific modules here
  ];

  # HTPC user-specific configuration for DEX5550
  home.packages = with pkgs; [
    # Media applications
    vlc
    mpv
    kodi
    plex-media-player

    # Audio/Video tools
    pavucontrol
    alsamixer

    # File management
    ranger
    mc

    # Remote control tools
    anydesk
    teamviewer
  ];

  # HTPC-specific programs
  programs = {
    git = {
      enable = true;
      userName = "HTPC User";
      userEmail = "htpcuser@example.com";
    };

    # Media-focused browser
    firefox.enable = true;
  };

  # HTPC-specific services
  services = {
    # Add any HTPC-specific services here
  };

  # HTPC-specific settings
  home.sessionVariables = {
    # Set default media player
    BROWSER = "firefox";
  };
}
