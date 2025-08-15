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

    # Fix PATH ordering to prioritize wrappers (fixes sudo setuid issue)
    # This ensures /run/wrappers/bin comes before /run/current-system/sw/bin
    PATH = lib.mkForce "/run/wrappers/bin:\${PATH}";
  };
}
