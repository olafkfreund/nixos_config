# configuration
{ config, pkgs, ... }:

{
  imports = [
    ./users.nix 
    ./networking.nix
    ./programs.nix
    ./ssh.nix
  ];
  
  systemd.services."getty@tty3".enable = false;
  systemd.services."autovt@tty3".enable = false; 
  boot.isContainer = true;
  system.stateVersion = "24.11";
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  networking.firewall.enable = true;
}
