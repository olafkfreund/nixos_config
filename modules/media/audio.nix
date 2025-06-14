{
  config,
  lib,
  pkgs,
  ...
}: {
  options.modules.media.audio = {
    enable = lib.mkEnableOption "audio support";

    server = lib.mkOption {
      type = lib.types.enum ["pipewire" "pulseaudio" "alsa"];
      default = "pipewire";
      description = "Audio server to use";
    };

    lowLatency = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable low-latency audio configuration";
    };

    extraPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = with pkgs; [
        pavucontrol
        playerctl
        pulsemixer
      ];
      description = "Additional audio packages to install";
    };

    bluetooth = {
      enable = lib.mkEnableOption "Bluetooth audio support";
      codec = lib.mkOption {
        type = lib.types.enum ["sbc" "aac" "aptx" "ldac"];
        default = "sbc";
        description = "Preferred Bluetooth audio codec";
      };
    };
  };

  config = lib.mkIf config.modules.media.audio.enable {
    sound.enable = true;
    security.rtkit.enable = true;

    # PipeWire configuration
    services.pipewire = lib.mkIf (config.modules.media.audio.server == "pipewire") {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      jack.enable = config.modules.media.audio.lowLatency;

      extraConfig.pipewire = lib.mkIf config.modules.media.audio.lowLatency {
        "context.properties" = {
          "default.clock.rate" = 48000;
          "default.clock.quantum" = 32;
          "default.clock.min-quantum" = 32;
          "default.clock.max-quantum" = 32;
        };
      };
    };

    # PulseAudio configuration - enable only when selected, disable when using PipeWire
    hardware.pulseaudio = {
      enable = config.modules.media.audio.server == "pulseaudio";
      support32Bit = lib.mkIf (config.modules.media.audio.server == "pulseaudio") true;
      package = lib.mkIf (config.modules.media.audio.server == "pulseaudio") pkgs.pulseaudioFull;
    };

    # Bluetooth audio
    hardware.bluetooth = lib.mkIf config.modules.media.audio.bluetooth.enable {
      enable = true;
      powerOnBoot = true;
      settings = {
        General = {
          Enable = "Source,Sink,Media,Socket";
        };
      };
    };

    services.blueman.enable = lib.mkIf config.modules.media.audio.bluetooth.enable true;

    # Install audio packages
    environment.systemPackages = config.modules.media.audio.extraPackages;

    # User groups for audio access
    users.users = lib.mkMerge [
      (lib.mkIf (config.users.users ? "olafkfreund") {
        olafkfreund.extraGroups = ["audio"];
      })
    ];
  };
}
