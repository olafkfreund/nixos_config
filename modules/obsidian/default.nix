{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.programs.obsidian.enable;
in {
  options.programs.obsidian = {
    enable = mkEnableOption "Obsidian markdown editor";
  };

  config = mkIf cfg {
    environment.systemPackages = with pkgs; [
      obsidian
      obsidian-export
    ];
  };
}
