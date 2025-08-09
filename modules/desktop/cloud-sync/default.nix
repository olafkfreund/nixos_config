{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    celeste
    rclone
  ];
}
