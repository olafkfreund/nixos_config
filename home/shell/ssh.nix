{ pkgs, ... }: {

home.packages = with pkgs; [
  sshs
  sshfs
  ];
}
