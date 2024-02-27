{ pkgs, ... }: {

home.packages = with pkgs; [
  cosmic-bg
  cosmic-osd
  cosmic-term
  cosmic-edit
  cosmic-comp
  cosmic-randr
  cosmic-panel
  cosmic-icons
  cosmic-files
  cosmic-session
  cosmic-greeter
  cosmic-applets
  cosmic-settings
  cosmic-launcher
  cosmic-protocols
  cosmic-screenshot
  cosmic-applibrary
  cosmic-notifications
  cosmic-settings-daemon
  cosmic-workspaces-epoch
  xdg-desktop-portal-cosmic
  ];
}
