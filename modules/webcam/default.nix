{ pkgs
, config
, lib
, ...
}:
let
  inherit (lib) mkIf;
  cfg = config.features.programs;
in
{
  config = mkIf cfg.webcam {
    environment.systemPackages = with pkgs; [
      better-adb-sync
    ];
  };
}
