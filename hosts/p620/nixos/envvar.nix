{ lib, ... }:
let
  vars = import ../variables.nix;
in
{
  environment.sessionVariables = vars.environmentVariables // {
    # Force override for Qt platform theme to align with system default
    QT_QPA_PLATFORMTHEME = lib.mkForce "qt5ct";
  };
}
