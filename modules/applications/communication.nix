{
  config,
  lib,
  pkgs,
  ...
}: {
  options.modules.applications.communication = {
    enable = lib.mkEnableOption "communication applications";

    chat = {
      enable = lib.mkEnableOption "chat applications";
      packages = lib.mkOption {
        type = lib.types.listOf lib.types.package;
        default = with pkgs; [
          discord
          telegram-desktop
          slack
          teams-for-linux
        ];
        description = "Chat application packages to install";
      };
    };

    email = {
      enable = lib.mkEnableOption "email clients";
      packages = lib.mkOption {
        type = lib.types.listOf lib.types.package;
        default = with pkgs; [
          thunderbird
          evolution
        ];
        description = "Email client packages to install";
      };
    };

    video = {
      enable = lib.mkEnableOption "video conferencing";
      packages = lib.mkOption {
        type = lib.types.listOf lib.types.package;
        default = with pkgs; [
          zoom-us
          skypeforlinux
        ];
        description = "Video conferencing packages to install";
      };
    };
  };

  config = lib.mkIf config.modules.applications.communication.enable {
    environment.systemPackages = lib.flatten [
      (lib.optionals config.modules.applications.communication.chat.enable
        config.modules.applications.communication.chat.packages)
      (lib.optionals config.modules.applications.communication.email.enable
        config.modules.applications.communication.email.packages)
      (lib.optionals config.modules.applications.communication.video.enable
        config.modules.applications.communication.video.packages)
    ];

    # Enable audio/video support for communication apps
    hardware.pulseaudio.enable =
      lib.mkIf
      (config.modules.applications.communication.video.enable
        || config.modules.applications.communication.chat.enable)
      false;

    security.rtkit.enable =
      lib.mkIf
      (config.modules.applications.communication.video.enable
        || config.modules.applications.communication.chat.enable)
      true;

    services.pipewire =
      lib.mkIf
      (config.modules.applications.communication.video.enable
        || config.modules.applications.communication.chat.enable) {
        enable = true;
        alsa.enable = true;
        alsa.support32Bit = true;
        pulse.enable = true;
      };

    # Enable camera support
    hardware.opengl = lib.mkIf config.modules.applications.communication.video.enable {
      enable = true;
      driSupport = true;
      driSupport32Bit = true;
    };
  };
}
