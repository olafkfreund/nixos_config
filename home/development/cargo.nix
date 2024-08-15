{ pkgs, pkgs-stable, ... }: {

home.packages = [
  pkgs-stable.cargo
  pkgs-stable.cargo-ui
  pkgs-stable.cargo-update
  pkgs.slumber
  pkgs.openapi-tui
  pkgs.clipse
  pkgs.systemctl-tui
  ];
}
