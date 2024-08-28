{ pkgs, ...
}: {
  xdg.mime.enable = true;
  xdg.autostart.enable = true;

  environment.systemPackages = with pkgs; [
    xdg-utils
    xdg-user-dirs
    xdg-launch
    desktop-file-utils
  ];
}
