{ pkgs, ... }:
{
home.packages = with pkgs; [
  (microsoft-edge.override {
      commandLineArgs = [
        "--enable-features=UseOzonePlatform"
        "--ozone-platform=wayland"
      ];
    })
  (microsoft-edge-dev.override {
      commandLineArgs = [
        "--enable-features=UseOzonePlatform"
        "--ozone-platform=wayland"
      ];
    })

];

}
