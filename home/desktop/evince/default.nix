{ lib
, config
, pkgs
, ...
}:
let
  inherit (lib) mkIf;
  cfg = config.features.desktop;
in
{
  config = mkIf (cfg.enable && cfg.evince) {
    home.packages = [ pkgs.evince ];
    xdg.mimeApps = {
      enable = true;
      associations.added = {
        "application/pdf" = [ "org.gnome.Evince.desktop" ];
      };
      defaultApplications = {
        "application/pdf" = [ "org.gnome.Evince.desktop" ];
      };
    };
  };
}
