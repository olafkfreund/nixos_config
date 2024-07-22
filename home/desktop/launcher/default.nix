{ config, pkgs, ... }:
{
  home = {
    packages = with pkgs; [
      rofi
      rofi-wayland
      yofi
    ];
  };
}
