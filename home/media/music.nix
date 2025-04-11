{
  pkgs,
  pkgs-stable,
  pkgs-unstable,
  ...
}: {
  home.packages = [
    pkgs.spotify
    # pkgs.spicetify-cli
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
  ];
}
