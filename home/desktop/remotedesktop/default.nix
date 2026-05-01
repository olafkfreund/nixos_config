{ pkgs
, config
, lib
, ...
}:
let
  inherit (lib) mkIf mkEnableOption;
  cfg = config.desktop.remotedesktop;
in
{
  options.desktop.remotedesktop = {
    enable = mkEnableOption {
      default = false;
      description = "Enable Remote Desktop";
    };
  };
  config = mkIf cfg.enable {
    home.packages = [
      pkgs.remmina
      pkgs.freerdp
    ];
  };
}
