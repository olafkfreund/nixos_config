{ pkgs, pkgs-stable, ... }: {

  home.packages = [
    #spotify
    pkgs.spicetify-cli
    pkgs.ncspot # Spotify
    pkgs.plexamp # Plex
    pkgs.vlc # video player
    pkgs.cava # audio visualizer
    # spotify-player # Spotify
    pkgs.sptlrx # Spotify Lyrics
    pkgs-stable.castero # Podcasts
    pkgs.gnome-podcasts # Podcasts
    pkgs.hypnotix

  ];

}
