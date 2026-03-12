{ config, lib, pkgs, ... }:
with lib;
let
  cfg = config.features.programs.reddix;
in
{
  options.features.programs.reddix = {
    enable = mkEnableOption "reddix Reddit TUI client";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [
      (pkgs.callPackage ../../pkgs/reddix { })
    ];
  };
}
