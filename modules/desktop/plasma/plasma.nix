{
  inputs,
  config,
  lib,
  pkgs,
  pkgs-stable,
  ...
}: let
  plasmaModules = import ../../common/plasma-packages.nix {inherit lib pkgs;};
in {
  environment.systemPackages = plasmaModules.plasmaCommonPackages;
}
