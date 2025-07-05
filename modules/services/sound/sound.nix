# Audio System Configuration Module
# Configures PipeWire audio system with Bluetooth support
{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.modules.services.sound;
in {
  options.modules.services.sound = {
    enable = mkEnableOption "PipeWire audio system";

    pipewire = {
      enableJack = mkOption {
        type = types.bool;
        default = false;
        description = ''Enable JACK support in PipeWire'';
        example = true;
      };

      enable32BitSupport = mkOption {
        type = types.bool;
        default = true;
        description = ''Enable 32-bit ALSA support'';
        example = false;
      };
    };

    bluetooth = {
      enableAdvancedCodecs = mkOption {
        type = types.bool;
        default = true;
        description = ''Enable advanced Bluetooth audio codecs (SBC-XQ, mSBC)'';
        example = false;
      };

      enableHardwareVolume = mkOption {
        type = types.bool;
        default = true;
        description = ''Enable hardware volume control for Bluetooth devices'';
        example = false;
      };
    };
  };

  config = mkIf cfg.enable {
    # Disable PulseAudio in favor of PipeWire
    services.pulseaudio = {
      enable = false;
      package = pkgs.pulseaudioFull;
    };

    # Enable real-time kit for audio performance
    security.rtkit.enable = true;

    # Configure PipeWire
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = cfg.pipewire.enable32BitSupport;
      pulse.enable = true;
      jack.enable = cfg.pipewire.enableJack;
    };

    # Bluetooth audio configuration
    services.pipewire.wireplumber.extraConfig = mkIf cfg.bluetooth.enableAdvancedCodecs {
      "monitor.bluez.properties" = {
        "bluez5.enable-sbc-xq" = true;
        "bluez5.enable-msbc" = true;
        "bluez5.enable-hw-volume" = cfg.bluetooth.enableHardwareVolume;
        "bluez5.roles" = ["hsp_hs" "hsp_ag" "hfp_hf" "hfp_ag"];
      };
    };

    # Validation
    assertions = [
      {
        assertion = cfg.pipewire.enableJack -> cfg.enable;
        message = "JACK support requires the sound module to be enabled";
      }
    ];

    # Helpful warnings
    warnings = [
      (mkIf cfg.pipewire.enableJack ''
        JACK support is enabled in PipeWire. This may conflict with other JACK installations.
        Ensure no other JACK daemons are running.
      '')
    ];
  };
}
