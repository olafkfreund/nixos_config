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
    security.wrappers.sunshine = {
        owner = "root";
        group = "root";
        capabilities = "cap_sys_admin+p";
        source = "${pkgs.sunshine}/bin/sunshine";
    };
  };
}
