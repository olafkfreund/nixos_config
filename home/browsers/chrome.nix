{ pkgs, ... }: {

home.packages = with pkgs; [
  google-chrome
];
nixpkgs.config.chromium.commandLineArgs = "--enable-features=UseOzonePlatform --ozone-platform=wayland";
}
