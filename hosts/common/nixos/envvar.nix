# Consolidated envvar.nix - used by all hosts
{ lib, ... }:
let
  sharedVars = import ../shared-variables.nix;
in
{
  environment.sessionVariables = sharedVars.baseEnvironment // {
    QT_QPA_PLATFORMTHEME = lib.mkForce "qt5ct";
  };
}
