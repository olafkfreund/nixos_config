{ inputs, pkgs, ... }:

{
  home.packages = with pkgs; [
    droidcam
    adb-sync
    ];
}
