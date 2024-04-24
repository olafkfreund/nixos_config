{ pkgs, ... }:
let
  username = "olafkfreund";
in
{
  services = {
    printing.enable = true;
    avahi = {
      enable = true;
      nssmdns4 = true;
      openFirewall = true;
    };
    ipp-usb.enable = true;
  };
  hardware.sane = {
    enable = true;
    extraBackends = [pkgs.hplipWithPlugin];
    disabledDefaultBackends = ["escl"];
  };
  services.printing.drivers = [ pkgs.hplipWithPlugin ];
  programs.system-config-printer.enable = true;
  users.users.${username}.extraGroups = ["scanner" "lp"];
}
