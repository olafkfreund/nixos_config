{
  pkgs,
  lib,
  config,
  ...
}:
with lib; let
  cfg = programs.virt.nemu;
in {
  options.virt.nemu = {
    enable = mkEnableOption {
      default = false;
      description = "Nemu";
    };
  };
  config = mkIf cfg.enable {
    programs.nemu = {
      package = pkgs._nemu;
      enable = true;
      vhostNetGroup = "vhost";
      macvtapGroup = "vhost";
      usbGroup = "usb";
      users = {
        serpentian = {
          autoAddVeth = true;
          autoStartDaemon = true;
        };
      };
    };
  };
}
