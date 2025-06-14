{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.custom.gaming.steam;
in {
  options.custom.gaming.steam = {
    enable = lib.mkEnableOption "Steam gaming platform";

    compatibility = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable compatibility layers (Proton, etc.)";
      };
    };

    remotePlay = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable Steam Remote Play";
      };
    };

    vr = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable VR support";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    # Enable Steam
    programs.steam = {
      enable = true;
      remotePlay.openFirewall = cfg.remotePlay.enable;
      dedicatedServer.openFirewall = true;

      # Enable compatibility layers
      extraCompatPackages = lib.optionals cfg.compatibility.enable (with pkgs; [
        proton-ge-bin
      ]);
    };

    # Gaming-specific packages
    environment.systemPackages = with pkgs;
      [
        # Steam utilities
        steamtinkerlaunch
        steam-run
      ]
      ++ lib.optionals cfg.compatibility.enable [
        # Compatibility tools
        lutris
        bottles
        wine
        winetricks
      ]
      ++ lib.optionals cfg.vr.enable [
        # VR support
        # Will be added when VR packages are available
      ];

    # Gaming optimizations
    boot.kernel.sysctl = {
      # Increase map count for some games
      "vm.max_map_count" = 2147483642;
    };

    # Enable GameMode for performance
    programs.gamemode.enable = true;
  };
}
