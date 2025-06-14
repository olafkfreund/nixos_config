{
  config,
  lib,
  pkgs,
  ...
}: {
  options.modules.gaming.emulation = {
    enable = lib.mkEnableOption "gaming emulation support";

    retroarch = {
      enable = lib.mkEnableOption "RetroArch emulation";
      cores = lib.mkOption {
        type = lib.types.listOf lib.types.package;
        default = with pkgs.libretro; [
          beetle-psx-hw
          snes9x
          mgba
          nestopia
          mupen64plus
        ];
        description = "RetroArch cores to install";
      };
    };

    dolphin = {
      enable = lib.mkEnableOption "Dolphin GameCube/Wii emulator";
    };

    pcsx2 = {
      enable = lib.mkEnableOption "PCSX2 PlayStation 2 emulator";
    };

    rpcs3 = {
      enable = lib.mkEnableOption "RPCS3 PlayStation 3 emulator";
    };

    yuzu = {
      enable = lib.mkEnableOption "Yuzu Nintendo Switch emulator";
    };

    wine = {
      enable = lib.mkEnableOption "Wine Windows compatibility";
      variant = lib.mkOption {
        type = lib.types.enum ["wine" "wine-staging" "wine-wayland"];
        default = "wine-staging";
        description = "Wine variant to use";
      };
    };

    dosbox = {
      enable = lib.mkEnableOption "DOSBox DOS emulator";
    };
  };

  config = lib.mkIf config.modules.gaming.emulation.enable {
    environment.systemPackages = lib.flatten [
      # RetroArch
      (lib.optionals config.modules.gaming.emulation.retroarch.enable [
        (pkgs.retroarch.override {
          cores = config.modules.gaming.emulation.retroarch.cores;
        })
      ])

      # Individual emulators
      (lib.optionals config.modules.gaming.emulation.dolphin.enable [
        pkgs.dolphin-emu
      ])

      (lib.optionals config.modules.gaming.emulation.pcsx2.enable [
        pkgs.pcsx2
      ])

      (lib.optionals config.modules.gaming.emulation.rpcs3.enable [
        pkgs.rpcs3
      ])

      (lib.optionals config.modules.gaming.emulation.yuzu.enable [
        pkgs.yuzu-mainline
      ])

      # Wine
      (lib.optionals config.modules.gaming.emulation.wine.enable [
        (
          if config.modules.gaming.emulation.wine.variant == "wine-staging"
          then pkgs.wineWowPackages.staging
          else if config.modules.gaming.emulation.wine.variant == "wine-wayland"
          then pkgs.wineWowPackages.waylandFull
          else pkgs.wineWowPackages.stable
        )
        pkgs.winetricks
        pkgs.bottles
      ])

      # DOSBox
      (lib.optionals config.modules.gaming.emulation.dosbox.enable [
        pkgs.dosbox
        pkgs.dosbox-staging
      ])
    ];

    # Hardware requirements for emulation
    hardware.opengl = {
      enable = true;
      driSupport = true;
      driSupport32Bit = true;
    };

    # Audio support for emulators
    hardware.pulseaudio.support32Bit =
      lib.mkIf
      (config.modules.gaming.emulation.wine.enable
        || config.modules.gaming.emulation.retroarch.enable)
      true;

    # Fonts for Wine
    fonts.packages = lib.mkIf config.modules.gaming.emulation.wine.enable (with pkgs; [
      corefonts
      vistafonts
      liberation_ttf
    ]);

    # User groups for controller access
    users.users = lib.mkMerge [
      (lib.mkIf (config.users.users ? "olafkfreund") {
        olafkfreund.extraGroups = ["input"];
      })
    ];
  };
}
