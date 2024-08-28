{ pkgs, ... }:
{
home.packages = with pkgs; [
  microsoft-edge
  microsoft-edge-dev
];

}
