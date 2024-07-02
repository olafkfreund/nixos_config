{
  config,
  pkgs,
  imports,
  ...
}: 
let
  spotify-player = pkgs.callPackage ./spotify-player-pkgs.nix {};
in {
  disabledModules = ["programs/spotify-player.nix"];
  imports = [./spotify-player-cfg.nix];

  programs.spotify-player = {
    enable = true;
    package = spotify-player;
    settings = {
      client_id = "65b708073fc0480ea92a077233ca87bd";
      client_port = 8080;
      play_icon = " ";
      pause_icon = " ";
      enable_media_control = true;
      # theme = config.stylix.base16Scheme.slug;
      default_device = "spotify-player";
      max_playlist_size = 20;
      max_history_size = 20;
      seek_duration_secs = 10;
      playback_window_position = "Bottom";
      liked_icon = " ";
      border_type = "Hidden";
      progress_bar_type = "Rectangle";
      cover_img_scale = 1;
      cover_img_length = 12;
      cover_img_width = 5;
      player_event_hook_command.command = pkgs.writeShellScript "waybarHook" ''
        sleep 1
        curl "$(playerctl -p spotify_player metadata mpris:artUrl)" > /tmp/cover.jpg
        pkill -RTMIN+8 waybar
      '';
      device = {
        name = "spotify-player";
        device_type = "speaker";
        bitrate = 320;
        audio_cache = false;
        autoplay = true;
      };
    };
  };
}
