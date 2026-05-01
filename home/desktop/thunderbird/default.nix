{ config
, lib
, pkgs-unstable
, ...
}:
let
  inherit (lib) mkIf;
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
