{ config
, lib
, pkgs
, ...
}:
with lib; let
  username = "olafkfreund";
  cfg = config.services.print;
in
{
  options.services.print = {
    enable = mkEnableOption {
      default = false;
      description = "Enable the HP print service";
    };
  };
  config = mkIf cfg.enable {
    services = {
      printing.enable = true;
      avahi = {
        enable = true;
        nssmdns4 = true;
        nssmdns6 = true;
        openFirewall = true;
        ipv4 = true;
        ipv6 = true;
        publish = {
          enable = true;
          addresses = true;
          workstation = true;
        };
      };
      ipp-usb.enable = true;
    };
    hardware.sane = {
      enable = true;
      extraBackends = [ pkgs.hplip ];
      disabledDefaultBackends = [ "escl" ];
    };
    services.printing.drivers = [ pkgs.hplip ];
    programs.system-config-printer.enable = true;
    users.users.${username}.extraGroups = [ "scanner" "lp" ];
    environment.systemPackages = [
      pkgs.hplip
      pkgs.xsane
      pkgs.sane-airscan
      pkgs.simple-scan
      pkgs.system-config-printer
      pkgs.ghostscript
      pkgs.cups
      pkgs.gawk
    ];
  };
}
