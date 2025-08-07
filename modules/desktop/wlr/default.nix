{
  pkgs,
  ...
}: {
  environment.systemPackages = [
    pkgs.waypaper
    pkgs.wl-clipboard
    pkgs.wlogout
    pkgs.wlroots
    pkgs.wlr-randr
    pkgs.wdisplays
    pkgs.wl-screenrec
  ];
}
