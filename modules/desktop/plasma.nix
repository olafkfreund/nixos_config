{
  config,
  lib,
  pkgs,
  ...
}: {
  options.custom.desktop.plasma = {
    enable = lib.mkEnableOption "KDE Plasma desktop environment";

    version = lib.mkOption {
      type = lib.types.enum ["5" "6"];
      default = "6";
      description = "Plasma version to use";
    };

    applications = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable KDE applications";
      };

      packages = lib.mkOption {
        type = lib.types.listOf lib.types.package;
        default = with pkgs.kdePackages; [
          dolphin
          kate
          konsole
          gwenview
          okular
          spectacle
          ark
        ];
        description = "KDE application packages to install";
      };
    };

    wayland = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable Wayland support for Plasma";
    };
  };

  config = lib.mkIf config.custom.desktop.plasma.enable {
    # Enable KDE Plasma
    services.xserver = {
      enable = true;
      desktopManager.plasma5.enable = lib.mkIf (config.custom.desktop.plasma.version == "5") true;
    };

    services.displayManager.sddm = {
      enable = true;
      wayland.enable = config.custom.desktop.plasma.wayland;
    };

    services.desktopManager.plasma6.enable = lib.mkIf (config.custom.desktop.plasma.version == "6") true;

    # Install KDE applications
    environment.systemPackages =
      lib.optionals config.custom.desktop.plasma.applications.enable
      config.custom.desktop.plasma.applications.packages;

    # Enable KDE Connect
    programs.kdeconnect.enable = true;

    # Enable Plasma-specific services
    programs.dconf.enable = true;
  };
}
