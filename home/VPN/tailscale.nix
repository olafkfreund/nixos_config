{ pkgs, pkgs-stable, ... }: {

home.packages = with pkgs; [
  
  tailscale
  ktailctl
  ];
}
