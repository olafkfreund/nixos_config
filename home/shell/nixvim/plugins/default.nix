{
  config,
  lib,
  pkgs,
  ...
}: {
  imports = [
    # Core plugins
    ./core

    # Editor plugins
    ./editor

    # UI plugins
    ./ui

    # Coding plugins
    ./coding

    # Language specific plugins
    ./lang
  ];
}
