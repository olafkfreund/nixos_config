{ pkgs, ... }: {

  home.packages = with pkgs; [
    celeste
    rclone
  ];
}
