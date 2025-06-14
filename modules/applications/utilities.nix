{
  config,
  lib,
  pkgs,
  ...
}: {
  options.modules.applications.utilities = {
    enable = lib.mkEnableOption "utility applications";

    archive = {
      enable = lib.mkEnableOption "archive utilities";
      packages = lib.mkOption {
        type = lib.types.listOf lib.types.package;
        default = with pkgs; [
          p7zip
          unzip
          zip
          rar
          unrar
        ];
        description = "Archive utility packages to install";
      };
    };

    file = {
      enable = lib.mkEnableOption "file management utilities";
      packages = lib.mkOption {
        type = lib.types.listOf lib.types.package;
        default = with pkgs; [
          dolphin
          nautilus
          ranger
          mc
        ];
        description = "File manager packages to install";
      };
    };

    system = {
      enable = lib.mkEnableOption "system utilities";
      packages = lib.mkOption {
        type = lib.types.listOf lib.types.package;
        default = with pkgs; [
          htop
          btop
          neofetch
          tree
          fd
          ripgrep
          bat
          eza
        ];
        description = "System utility packages to install";
      };
    };

    network = {
      enable = lib.mkEnableOption "network utilities";
      packages = lib.mkOption {
        type = lib.types.listOf lib.types.package;
        default = with pkgs; [
          wget
          curl
          nmap
          wireshark
        ];
        description = "Network utility packages to install";
      };
    };
  };

  config = lib.mkIf config.modules.applications.utilities.enable {
    environment.systemPackages = lib.flatten [
      (lib.optionals config.modules.applications.utilities.archive.enable
        config.modules.applications.utilities.archive.packages)
      (lib.optionals config.modules.applications.utilities.file.enable
        config.modules.applications.utilities.file.packages)
      (lib.optionals config.modules.applications.utilities.system.enable
        config.modules.applications.utilities.system.packages)
      (lib.optionals config.modules.applications.utilities.network.enable
        config.modules.applications.utilities.network.packages)
    ];

    # Enable special permissions for network utilities
    programs.wireshark.enable =
      lib.mkIf
      (config.modules.applications.utilities.network.enable
        && lib.any (pkg: pkg.pname or pkg.name == "wireshark")
        config.modules.applications.utilities.network.packages)
      true;
  };
}
