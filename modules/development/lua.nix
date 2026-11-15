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
  config = mkIf (cfg.enable && cfg.lua) {
    environment.systemPackages =
      [
        pkgs.lua
        pkgs.stylua
        pkgs.lua-language-server
      ];
  };
}
