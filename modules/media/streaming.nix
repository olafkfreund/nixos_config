{
  config,
  lib,
  pkgs,
  ...
}: {
  options.modules.media.streaming = {
    enable = lib.mkEnableOption "streaming and broadcasting support";

    obs = {
      enable = lib.mkEnableOption "OBS Studio";
      plugins = lib.mkOption {
        type = lib.types.listOf lib.types.package;
        default = with pkgs.obs-studio-plugins; [
          wlrobs
          obs-backgroundremoval
          obs-pipewire-audio-capture
        ];
        description = "OBS Studio plugins to install";
      };
    };

    streaming = {
      enable = lib.mkEnableOption "streaming platforms";
      packages = lib.mkOption {
        type = lib.types.listOf lib.types.package;
        default = with pkgs; [
          streamlink
          yt-dlp
        ];
        description = "Streaming platform packages to install";
      };
    };

    recording = {
      enable = lib.mkEnableOption "screen recording tools";
      packages = lib.mkOption {
        type = lib.types.listOf lib.types.package;
        default = with pkgs; [
          simplescreenrecorder
          peek
          asciinema
        ];
        description = "Recording tool packages to install";
      };
    };

    live = {
      enable = lib.mkEnableOption "live streaming tools";
      packages = lib.mkOption {
        type = lib.types.listOf lib.types.package;
        default = with pkgs; [
          ffmpeg
          v4l-utils
        ];
        description = "Live streaming packages to install";
      };
    };
  };

  config = lib.mkIf config.modules.media.streaming.enable {
    environment.systemPackages = lib.flatten [
      (lib.optionals config.modules.media.streaming.obs.enable
        [
          (pkgs.obs-studio.override {
            plugins = config.modules.media.streaming.obs.plugins;
          })
        ])
      (lib.optionals config.modules.media.streaming.streaming.enable
        config.modules.media.streaming.streaming.packages)
      (lib.optionals config.modules.media.streaming.recording.enable
        config.modules.media.streaming.recording.packages)
      (lib.optionals config.modules.media.streaming.live.enable
        config.modules.media.streaming.live.packages)
    ];

    # Enable camera and audio support for streaming
    hardware.opengl = {
      enable = true;
      driSupport = true;
      driSupport32Bit = true;
    };

    # Video4Linux support
    boot.kernelModules = lib.mkIf config.modules.media.streaming.live.enable [
      "v4l2loopback"
    ];

    boot.extraModulePackages = lib.mkIf config.modules.media.streaming.live.enable [
      config.boot.kernelPackages.v4l2loopback
    ];

    # User groups for video access
    users.users = lib.mkMerge [
      (lib.mkIf (config.users.users ? "olafkfreund") {
        olafkfreund.extraGroups = ["video"];
      })
    ];
  };
}
