{ pkgs, ... }:
{
  environment.systemPackages = [
    pkgs.wlr-randr
    pkgs.wdisplays
  ];
}
