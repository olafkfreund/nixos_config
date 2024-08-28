{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.programs.thunderbird.enable;
in {
  config = mkIf cfg {
    programs.thunderbird = {
      enable = true;
      package = pkgs.thunderbird;
    };
  };
}
