{ config
, lib
, pkgs-unstable
, ...
}:
with lib; let
  cfg = config.programs.thunderbird.enable;
in
{
  config = mkIf cfg {
    programs.thunderbird = {
      enable = true;
      package = pkgs-unstable.thunderbird;
    };
  };
}
