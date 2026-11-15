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
  config = mkIf (cfg.enable && cfg.java) {
    environment.systemPackages =
      [
        pkgs.zulu25
        pkgs.gradle
        pkgs.maven
        # pkgs.jetbrains.idea-community-bin
      ];
  };
}
