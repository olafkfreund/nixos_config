{
  config,
  lib,
  pkgs,
  ...
}: {
  options.modules.applications.media = {
    enable = lib.mkEnableOption "media applications";

    players = {
      enable = lib.mkEnableOption "media players";
      packages = lib.mkOption {
        type = lib.types.listOf lib.types.package;
        default = with pkgs; [
          vlc
          mpv
          spotify
        ];
        description = "Media player packages to install";
      };
    };

    editing = {
      enable = lib.mkEnableOption "media editing tools";
      packages = lib.mkOption {
        type = lib.types.listOf lib.types.package;
        default = with pkgs; [
          audacity
          kdenlive
          gimp
          inkscape
        ];
        description = "Media editing packages to install";
      };
    };

    streaming = {
      enable = lib.mkEnableOption "streaming applications";
      packages = lib.mkOption {
        type = lib.types.listOf lib.types.package;
        default = with pkgs; [
          obs-studio
          discord
        ];
        description = "Streaming and communication packages";
      };
    };
  };

  config = lib.mkIf config.modules.applications.media.enable {
    environment.systemPackages = lib.flatten [
      (lib.optionals config.modules.applications.media.players.enable
        config.modules.applications.media.players.packages)
      (lib.optionals config.modules.applications.media.editing.enable
        config.modules.applications.media.editing.packages)
      (lib.optionals config.modules.applications.media.streaming.enable
        config.modules.applications.media.streaming.packages)
    ];

    # Enable hardware acceleration for media applications
    hardware.opengl = lib.mkIf config.modules.applications.media.players.enable {
      enable = true;
      driSupport = true;
      driSupport32Bit = true;
    };

    # Enable audio for media applications
    sound.enable = lib.mkIf config.modules.applications.media.players.enable true;
    hardware.pulseaudio.enable = lib.mkIf config.modules.applications.media.players.enable false;
    security.rtkit.enable = lib.mkIf config.modules.applications.media.players.enable true;
    services.pipewire = lib.mkIf config.modules.applications.media.players.enable {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
    };
  };
}
