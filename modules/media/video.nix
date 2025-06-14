{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.custom.media.video;
in {
  options.custom.media.video = {
    enable = lib.mkEnableOption "video applications and codecs";

    players = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable video players";
      };

      apps = lib.mkOption {
        type = lib.types.listOf (lib.types.enum ["vlc" "mpv" "celluloid"]);
        default = ["vlc" "mpv"];
        description = "Video players to install";
      };
    };

    editing = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable video editing applications";
      };

      professional = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable professional video editing tools";
      };
    };

    codecs = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable video codecs";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    # Enable video support in hardware OpenGL
    hardware.opengl = {
      enable = true;
      extraPackages = with pkgs;
        lib.optionals cfg.codecs.enable [
          # Video acceleration packages will be added by hardware profiles
        ];
    };

    environment.systemPackages = with pkgs;
      [
        # Basic video tools
      ]
      ++ lib.optionals cfg.players.enable (
        lib.flatten (map (
            player:
              if player == "vlc"
              then [vlc]
              else if player == "mpv"
              then [mpv]
              else if player == "celluloid"
              then [celluloid]
              else []
          )
          cfg.players.apps)
      )
      ++ lib.optionals cfg.editing.enable [
        # Basic video editing
        kdenlive
        openshot-qt
      ]
      ++ lib.optionals cfg.editing.professional [
        # Professional video editing
        blender
        davinci-resolve
      ]
      ++ lib.optionals cfg.codecs.enable [
        # Codec support
        ffmpeg-full
        gstreamer
        gst_all_1.gstreamer
        gst_all_1.gst-plugins-base
        gst_all_1.gst-plugins-good
        gst_all_1.gst-plugins-bad
        gst_all_1.gst-plugins-ugly
      ];
  };
}
