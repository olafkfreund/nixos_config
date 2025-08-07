{ pkgs, ... }: {
  home.packages = [
    # pkgs.spotify # Removing direct Spotify installation (provided by Spicetify)
    pkgs.ncspot # Spotify
    pkgs.plexamp # Plex
    pkgs.vlc # video player
    pkgs.cava # audio visualizer
    pkgs.spotify-player # Spotify
    pkgs.sptlrx # Spotify Lyrics
    pkgs.castero # Podcasts
    pkgs.gnome-podcasts # Podcasts
    pkgs.hypnotix
    pkgs.parabolic
    pkgs.musicpod
    pkgs.spicetify-cli
    pkgs.playerctl # Required dependency for our script
    (pkgs.callPackage ../../pkgs/mpris-album-art { }) # Our album art script
  ];
}
