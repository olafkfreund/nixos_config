{ lib, ... }:
let
  vars = import ../variables.nix { };
in
{
  environment.sessionVariables = vars.environmentVariables // {
    QT_QPA_PLATFORMTHEME = lib.mkForce "qt5ct";
  };
}
