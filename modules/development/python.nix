{ config
, lib
, pkgs
, ...
}:
let
  inherit (lib) mkIf;
  cfg = config.features.development;
in
{
  config = mkIf (cfg.enable && cfg.python) {
    environment.systemPackages =
      [
        pkgs.python3
        pkgs.python3Packages.pip
        pkgs.python3Packages.pynvim
        pkgs.python3Packages.pynvim-pp
        pkgs.python3Packages.dbus-python
        pkgs.python3Packages.ninja
        pkgs.python3Packages.material-color-utilities
        pkgs.python3Packages.numpy
        pkgs.python3Packages.pyyaml
        pkgs.python3Packages.google-generativeai
        pkgs.python3Packages.google
        pkgs.python3Packages.google-auth
        pkgs.python3Packages.syncedlyrics
        pkgs.python3Packages.pygobject3
        pkgs.python3Packages.pycairo
        pkgs.python3Packages.pillow
        pkgs.python3Packages.requests
        pkgs.python3Packages.mcp

      ];
  };
}
