{ pkgs, ... }: {

  environment.systemPackages = with pkgs; [
    sshs # ssh server
    sshfs # ssh filesystem
    sshx # ssh with x forwarding
  ];
}
