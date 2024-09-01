{
  config,
  lib,
  ...
}:
with lib; let
  cfg = config.services.sunshine;
in {
  options.services.sunshine = {
    enable = mkEnableOption {
      default = false;
      description = "Enable screen sharing via Sunshine";
    };
  };
  config = mkIf cfg.enable {
    services.sunshine = {
      enable = true;
      autoStart = true;
      capSysAdmin = true;
    };
  };
}
