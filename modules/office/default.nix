{ config
, lib
, pkgs
, ...
}:
let
  inherit (lib) mkIf;
  cfg = config.features.programs;
in
{
  config = mkIf cfg.office {
    environment.systemPackages = with pkgs; [
      libreoffice-stable
    ];
  };
}
