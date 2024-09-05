{ pkgs, ... }:
{
  boot.plymouth.enable = true;
  boot.plymouth.theme = "nixos-bgrt";
  boot.plymouth.themePackages = [ pkgs.nixos-bgrt-plymouth ];
}
