# networking
{ lib, ...}:

{
  networking.firewall.enable = true;

  # resolve ip from a dhcp router (as containerized)
  networking.useDHCP = lib.mkForce true;
}
