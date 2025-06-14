{
  config,
  lib,
  pkgs,
  ...
}: {
  options.modules.hardware.laptop = {
    enable = lib.mkEnableOption "laptop hardware support";

    touchpad = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable touchpad support";
      };
    };

    backlight = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable backlight control";
      };
    };

    wireless = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable wireless networking";
      };
    };

    battery = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable battery monitoring";
      };
    };
  };

  config = lib.mkIf config.modules.hardware.laptop.enable {
    # Touchpad support
    services.xserver.libinput = lib.mkIf config.modules.hardware.laptop.touchpad.enable {
      enable = true;
      touchpad = {
        tapping = true;
        naturalScrolling = true;
        middleEmulation = true;
        disableWhileTyping = true;
      };
    };

    # Backlight control
    programs.light.enable = lib.mkIf config.modules.hardware.laptop.backlight.enable true;

    # Wireless support
    networking.wireless.enable = lib.mkIf config.modules.hardware.laptop.wireless.enable false;
    networking.networkmanager.enable = lib.mkIf config.modules.hardware.laptop.wireless.enable true;

    # Battery monitoring
    services.upower.enable = lib.mkIf config.modules.hardware.laptop.battery.enable true;

    # Laptop-specific services
    services.logind = {
      lidSwitch = "suspend";
      lidSwitchExternalPower = "lock";
    };

    # Power management
    powerManagement.enable = true;
    services.thermald.enable = true;

    # Hardware support
    hardware.bluetooth.enable = lib.mkDefault true;
    hardware.firmware = with pkgs; [
      linux-firmware
    ];
  };
}
