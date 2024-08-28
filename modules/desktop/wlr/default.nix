{ pkgs, ... }: {

environment.systemPackages = with pkgs; [
  waypaper
  wl-clipboard
  wlogout
  wlroots
  wlr-randr
  wdisplays
  wf-recorder
  wl-screenrec
  ];
}
