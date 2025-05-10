{
  pkgs,
  lib,
  ...
}: let
  plasmaModules = import ../../../modules/common/plasma-packages.nix {inherit lib pkgs;};
in {
  home.packages =
    plasmaModules.plasmaCommonPackages
    ++ plasmaModules.plasmaHomePackages;
}
