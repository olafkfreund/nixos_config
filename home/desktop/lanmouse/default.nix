{
  pkgs,
  inputs,
  config,
  lib,
  ...
}:
with lib; let
  cfg = config.lanmouse;
in {
  options.lanmouse = {
    enable = mkEnableOption "lan-mouse cross-platform mouse and keyboard sharing software for Linux, Windows and MacOS";
  };

  config = mkIf cfg.enable {
    programs.lan-mouse = {
      enable = true;
      # systemd = true;
      # package = inputs.lan-mouse.packages.${pkgs.stdenv.hostPlatform.system}.default;
      # Optional configuration in nix syntax, see config.toml for available options
      # settings = { };
    };
  };
}
