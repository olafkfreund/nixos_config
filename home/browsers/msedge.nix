{ pkgs, ... }:
{
home.packages = with pkgs; [
  microsoft-edge
  microsoft-edge-beta
  microsoft-edge-dev
];

}
