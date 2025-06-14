{
  config,
  lib,
  pkgs,
  ...
}: {
  options.modules.gaming.utilities = {
    enable = lib.mkEnableOption "gaming utilities and tools";

    launchers = {
      enable = lib.mkEnableOption "game launchers";
      packages = lib.mkOption {
        type = lib.types.listOf lib.types.package;
        default = with pkgs; [
          lutris
          heroic
          bottles
          prismlauncher # Minecraft
        ];
        description = "Game launcher packages to install";
      };
    };

    overlay = {
      enable = lib.mkEnableOption "gaming overlays";
      packages = lib.mkOption {
        type = lib.types.listOf lib.types.package;
        default = with pkgs; [
          mangohud
          goverlay
        ];
        description = "Gaming overlay packages to install";
      };
    };

    controllers = {
      enable = lib.mkEnableOption "controller support";
      packages = lib.mkOption {
        type = lib.types.listOf lib.types.package;
        default = with pkgs; [
          antimicrox
          jstest-gtk
          linuxConsoleTools
        ];
        description = "Controller utility packages to install";
      };
    };

    streaming = {
      enable = lib.mkEnableOption "game streaming";
      packages = lib.mkOption {
        type = lib.types.listOf lib.types.package;
        default = with pkgs; [
          moonlight-qt
          parsec-bin
        ];
        description = "Game streaming packages to install";
      };
    };

    modding = {
      enable = lib.mkEnableOption "game modding tools";
      packages = lib.mkOption {
        type = lib.types.listOf lib.types.package;
        default = with pkgs; [
          r2modman
          mod-organizer
        ];
        description = "Game modding packages to install";
      };
    };
  };

  config = lib.mkIf config.modules.gaming.utilities.enable {
    environment.systemPackages = lib.flatten [
      (lib.optionals config.modules.gaming.utilities.launchers.enable
        config.modules.gaming.utilities.launchers.packages)
      (lib.optionals config.modules.gaming.utilities.overlay.enable
        config.modules.gaming.utilities.overlay.packages)
      (lib.optionals config.modules.gaming.utilities.controllers.enable
        config.modules.gaming.utilities.controllers.packages)
      (lib.optionals config.modules.gaming.utilities.streaming.enable
        config.modules.gaming.utilities.streaming.packages)
      (lib.optionals config.modules.gaming.utilities.modding.enable
        config.modules.gaming.utilities.modding.packages)
    ];

    # Hardware support for gaming utilities
    hardware.opengl = {
      enable = true;
      driSupport = true;
      driSupport32Bit = true;
    };

    # Controller support
    hardware.steam-hardware.enable = lib.mkIf config.modules.gaming.utilities.controllers.enable true;

    services.udev.packages = lib.mkIf config.modules.gaming.utilities.controllers.enable [
      pkgs.game-devices-udev-rules
    ];

    # MangoHud configuration
    programs.mangohud =
      lib.mkIf
      (config.modules.gaming.utilities.overlay.enable
        && lib.any (pkg: pkg.pname or pkg.name == "mangohud")
        config.modules.gaming.utilities.overlay.packages) {
        enable = true;
        enableSessionWide = true;
      };

    # User groups for controller and hardware access
    users.users = lib.mkMerge [
      (lib.mkIf (config.users.users ? "olafkfreund") {
        olafkfreund.extraGroups = ["input" "plugdev"];
      })
    ];

    # Enable gamemode integration
    programs.gamemode.enable = lib.mkDefault true;
  };
}
