{ pkgs, ... }: {

home.packages = with pkgs; [
  cargo
  cargo-ui
  cargo-update
  ];
}
