{
  config,
  lib,
  pkgs,
  ...
}: {
  options.modules.hardware.desktop = {
    enable = lib.mkEnableOption "desktop hardware support";

    graphics = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable graphics acceleration";
      };
    };

    audio = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable audio hardware support";
      };
    };

    usb = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable USB device support";
      };
    };
  };

  config = lib.mkIf config.modules.hardware.desktop.enable {
    # Graphics support
    hardware.opengl = lib.mkIf config.modules.hardware.desktop.graphics.enable {
      enable = true;
      driSupport = true;
      driSupport32Bit = true;
    };

    # Audio support
    sound.enable = lib.mkIf config.modules.hardware.desktop.audio.enable true;
    hardware.pulseaudio.enable = lib.mkIf config.modules.hardware.desktop.audio.enable false;
    security.rtkit.enable = lib.mkIf config.modules.hardware.desktop.audio.enable true;

    # USB support
    services.udev.extraRules = lib.mkIf config.modules.hardware.desktop.usb.enable ''
      # USB device permissions
      SUBSYSTEM=="usb", MODE="0664", GROUP="plugdev"
    '';

    # Input devices
    services.xserver = lib.mkIf config.modules.hardware.desktop.graphics.enable {
      enable = lib.mkDefault false; # Only enable if desktop environment enables it
    };

    # Desktop-specific services
    services.udisks2.enable = lib.mkDefault true;
    services.upower.enable = lib.mkDefault true;
  };
}
