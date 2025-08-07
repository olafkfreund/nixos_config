{
  lib,
  config,
  pkgs,
  ...
}:
with lib; let
  cfg = config.programs.evince;
in {
  options.programs.evince = {
    enable = mkEnableOption {
      default = false;
      description = "Enable evince.";
    };
  };
  config = mkIf cfg.enable {
    home.packages = [pkgs.evince];
    xdg.mimeApps = {
      enable = true;
      associations.added = {
        "application/pdf" = ["org.gnome.Evince.desktop"];
      };
      defaultApplications = {
        "application/pdf" = ["org.gnome.Evince.desktop"];
      };
    };
  };
}
