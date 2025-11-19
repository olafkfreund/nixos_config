{ pkgs, ... }: {
  home.packages = [
    pkgs.spotify # Re-enabled while Spicetify is temporarily disabled (issue #13)
    pkgs.ncspot # Spotify
    pkgs.plexamp # Plex
    pkgs.vlc # video player
    pkgs.cava # audio visualizer
    pkgs.spotify-player # Spotify
    pkgs.sptlrx # Spotify Lyrics
    # pkgs.castero # Podcasts - DISABLED: Segfault with Python 3.13.9 (pytest check phase)
    pkgs.gnome-podcasts # Podcasts
    pkgs.hypnotix
    pkgs.wiremix # Music streaming
    pkgs.parabolic
    pkgs.musicpod
    pkgs.spicetify-cli
    pkgs.playerctl # Required dependency for our script
    (pkgs.callPackage ../../pkgs/mpris-album-art { }) # Our album art script
  ];
}
