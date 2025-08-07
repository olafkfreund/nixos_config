{ config
, lib
, pkgs
, ...
}:
with lib; let
  cfg = config.services.incus;
in
{
  options.services.incus = {
    enable = mkEnableOption {
      default = false;
      description = "Enable the Incus service.";
    };
  };
  config = mkIf cfg.enable {
    virtualisation = {
      incus = {
        package = pkgs.incus;
        enable = true;
      };
    };
    virtualisation.incus.ui.enable = true;
  };
}

