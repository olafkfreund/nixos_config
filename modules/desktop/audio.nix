{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.custom.desktop.audio;
in {
  options.custom.desktop.audio = {
    enable = lib.mkEnableOption "desktop audio support";

    server = lib.mkOption {
      type = lib.types.enum ["pipewire" "pulseaudio"];
      default = "pipewire";
      description = "Audio server to use";
    };

    lowLatency = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable low-latency audio configuration";
    };

    bluetooth = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable Bluetooth audio support";
      };

      codecs = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = ["sbc" "aac"];
        description = "Bluetooth audio codecs to support";
      };
    };

    extraPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [];
      description = "Additional audio packages to install";
    };
  };

  config = lib.mkIf cfg.enable {
    # PipeWire configuration (preferred)
    services.pipewire = lib.mkIf (cfg.server == "pipewire") {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      jack.enable = cfg.lowLatency;

      # Low-latency configuration
      extraConfig.pipewire."99-lowlatency" = lib.mkIf cfg.lowLatency {
        "context.properties" = {
          "default.clock.rate" = 48000;
          "default.clock.quantum" = 32;
          "default.clock.min-quantum" = 32;
          "default.clock.max-quantum" = 32;
        };
      };
    };

    # PulseAudio configuration (legacy)
    hardware.pulseaudio = lib.mkIf (cfg.server == "pulseaudio") {
      enable = true;
      support32Bit = true;
    };

    # Bluetooth support
    hardware.bluetooth = lib.mkIf cfg.bluetooth.enable {
      enable = true;
      powerOnBoot = true;
      settings = {
        General = {
          Enable = "Source,Sink,Media,Socket";
          Experimental = true;
        };
      };
    };

    # Audio packages
    environment.systemPackages = with pkgs;
      [
        # Audio control
        pavucontrol
        pulsemixer

        # Bluetooth management
      ]
      ++ lib.optionals cfg.bluetooth.enable [
        blueman
        bluetuith
      ]
      ++ lib.optionals cfg.lowLatency [
        # Professional audio tools
        qjackctl
        carla
      ]
      ++ cfg.extraPackages;

    # Enable real-time audio group for low-latency
    security.rtkit.enable = lib.mkIf cfg.lowLatency true;

    # Add users to audio group
    users.groups.audio = {};
  };
}
