{ pkgs, ... }:
{
home.packages = with pkgs; [
  # (microsoft-edge.override {
  #     commandLineArgs = [
  #       "--ozone-platform=wayland"
  #     ];
  #   })
  # (microsoft-edge-dev.override {
  #     commandLineArgs = [
  #       "--ozone-platform=wayland"
  #     ];
  #   })
  microsoft-edge
  microsoft-edge-dev
];

}
