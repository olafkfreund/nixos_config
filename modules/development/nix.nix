{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.nix.development;
in {
  options.nix.development = {
    enable = mkEnableOption "Enable Nix development environment";
    packages = mkOption {
      type = with types; listOf string;
      default = [
        # nix-init
        # nix-melt
      ];
      description = "Packages to install for Nix development";
    };
  };
  config = mkIf cfg.enable {
    environment.systemPackages = [
      pkgs.nurl
      pkgs.nixpkgs-fmt
      pkgs.nil
      pkgs.nixos-generators
    ] ++ cfg.packages;
  };
}
