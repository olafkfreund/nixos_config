{ inputs, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    droidcam
    adb-sync
    ];
}
