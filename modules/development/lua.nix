{ config, lib, pkgs, ... }:
with lib; let
  cfg = config.lua.development;
in {
  options.lua.development = {
    enable = mkEnableOption "Enable Lua development environment";
    packages = mkOption {
      type = with types; listOf str;
      default = [];
      description = "Packages to install for Lua development";
    };
  };
  config = mkIf cfg.enable {
    environment.systemPackages = [
      pkgs.lua
      pkgs.stylua
      pkgs.sumneko-lua-language-server 
    ] ++ cfg.packages;
  };
}

