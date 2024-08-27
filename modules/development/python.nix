{ config, lib, pkgs, ... }:
with lib; let
  cfg = config.python.development;
in {
  options.python.development = {
    enable = mkEnableOption "Enable Python development environment";
    packages = mkOption {
      type = with types; listOf string;
      default = [];
      description = "Packages to install for Python development";
    };
  };
  config = mkIf cfg.enable {
    environment.systemPackages = [
      pkgs.python3
      pkgs.python312Packages.pip
      pkgs.python312Packages.pynvim
      pkgs.python312Packages.pynvim-pp
      pkgs.python312Packages.dbus-python
      pkgs.python312Packages.ninja
      pkgs.python312Packages.material-color-utilities
      pkgs.python312Packages.numpy
      pkgs.python312Packages.pyyaml
      pkgs.python312Packages.google-generativeai
      pkgs.python312Packages.google
      pkgs.python312Packages.google-auth
      pkgs.python312Packages.syncedlyrics
      pkgs.python312Packages.pygobject3
      pkgs.python312Packages.pycairo
      pkgs.python312Packages.pillow
      pkgs.python312Packages.requests
    ] ++ cfg.packages;
  };
}

