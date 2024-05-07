{ pkgs, ... }: {

home.packages = with pkgs; [
  cargo
  cargo-ui
  cargo-update
  slumber
  openapi-tui
  clipse
  systemctl-tui
  ];
}
