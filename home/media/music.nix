{ pkgs, ... }: {
  home.packages = [
    pkgs.spotify # Official Spotify client
    pkgs.plexamp # Plex
    pkgs.vlc # video player
    pkgs.cava # audio visualizer
    pkgs.castero # Podcasts - Re-enabled: Python 3.13.9 compatibility fixed (issue #35 closed)
    pkgs.gnome-podcasts # Podcasts
    pkgs.hypnotix
    pkgs.wiremix # Music streaming
    pkgs.parabolic
    pkgs.musicpod
    pkgs.playerctl # Required dependency for our script
    (pkgs.callPackage ../../pkgs/mpris-album-art { }) # Our album art script
  ];
}
