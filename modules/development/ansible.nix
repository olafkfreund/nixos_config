{ config, lib, pkgs, ... }:
with lib; let
  cfg = config.ansible.development;
in
{
  options.ansible.development = {
    enable = mkEnableOption "Enable Ansible development environment";
    packages = mkOption {
      type = with types; listOf str;
      default = [ ];
      description = "Packages to install for Ansible development";
    };
  };
  config = mkIf cfg.enable {
    environment.systemPackages = [
      pkgs.ansible
      pkgs.ansible-lint
      # pkgs.ansible-navigator
    ] ++ cfg.packages;
  };
}

