# Consolidated envvar.nix - used by all hosts
# Sets environment variables from shared variables plus Qt platform theme override
{ lib, ... }:
let
  # Import shared variables directly
  sharedVars = import ../shared-variables.nix;
in
{
  environment.sessionVariables = sharedVars.baseEnvironment // {
    # Force override for Qt platform theme to align with system default
    QT_QPA_PLATFORMTHEME = lib.mkForce "qt5ct";
  };
}
