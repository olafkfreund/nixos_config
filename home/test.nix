{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.custom.homeManager;
in {
  options.custom.homeManager = {
    enable = mkEnableOption "Custom home-manager configuration";

    packages = mkOption {
      type = types.listOf types.package;
      default = [];
      description = "List of packages to install for the user";
    };

    installDevTools = mkEnableOption "Install development tools";
  };

  config = mkIf cfg.enable {
    home-manager.users.${config.user.name} = { pkgs, ... }: {
      home.packages = cfg.packages ++ (if cfg.installDevTools then [
        pkgs.cowsay
      ] else []);
    };
  };
}
