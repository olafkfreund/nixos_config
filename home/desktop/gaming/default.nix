{ pkgs, ... }: {
home.packages = with pkgs; [
  moonlight-qt
  looking-glass-client
  ];
}