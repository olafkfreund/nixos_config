{
  config,
  lib,
  pkgs,
  ...
}: {
  options.modules.applications.development = {
    enable = lib.mkEnableOption "development applications";

    editors = {
      enable = lib.mkEnableOption "code editors";
      packages = lib.mkOption {
        type = lib.types.listOf lib.types.package;
        default = with pkgs; [
          vscode
          neovim
          emacs
        ];
        description = "Code editor packages to install";
      };
    };

    languages = {
      enable = lib.mkEnableOption "programming language tools";
      packages = lib.mkOption {
        type = lib.types.listOf lib.types.package;
        default = with pkgs; [
          nodejs
          python3
          rustc
          cargo
          go
          gcc
        ];
        description = "Programming language packages to install";
      };
    };

    tools = {
      enable = lib.mkEnableOption "development tools";
      packages = lib.mkOption {
        type = lib.types.listOf lib.types.package;
        default = with pkgs; [
          git
          docker
          kubectl
          terraform
          ansible
        ];
        description = "Development tool packages to install";
      };
    };

    databases = {
      enable = lib.mkEnableOption "database tools";
      packages = lib.mkOption {
        type = lib.types.listOf lib.types.package;
        default = with pkgs; [
          postgresql
          redis
          sqlite
        ];
        description = "Database packages to install";
      };
    };
  };

  config = lib.mkIf config.modules.applications.development.enable {
    environment.systemPackages = lib.flatten [
      (lib.optionals config.modules.applications.development.editors.enable
        config.modules.applications.development.editors.packages)
      (lib.optionals config.modules.applications.development.languages.enable
        config.modules.applications.development.languages.packages)
      (lib.optionals config.modules.applications.development.tools.enable
        config.modules.applications.development.tools.packages)
      (lib.optionals config.modules.applications.development.databases.enable
        config.modules.applications.development.databases.packages)
    ];

    # Enable Docker daemon
    virtualisation.docker.enable =
      lib.mkIf
      (config.modules.applications.development.tools.enable
        && lib.any (pkg: pkg.pname or pkg.name == "docker")
        config.modules.applications.development.tools.packages)
      true;

    # Git configuration
    programs.git =
      lib.mkIf
      (config.modules.applications.development.tools.enable
        && lib.any (pkg: pkg.pname or pkg.name == "git")
        config.modules.applications.development.tools.packages) {
        enable = true;
      };
  };
}
