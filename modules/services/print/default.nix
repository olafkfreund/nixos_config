{
  pkgs,
  pkgs-stable,
  ...
}: let
  username = "olafkfreund";
in {
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
    extraBackends = [pkgs-stable.hplip];
    disabledDefaultBackends = ["escl"];
  };
  services.printing.drivers = [pkgs-stable.hplip];
  programs.system-config-printer.enable = true;
  users.users.${username}.extraGroups = ["scanner" "lp"];
}
