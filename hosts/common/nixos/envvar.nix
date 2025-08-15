# Consolidated envvar.nix - used by all hosts
# Sets environment variables from shared variables plus Qt platform theme override
{ lib, pkgs, ... }:
let
  # Import shared variables directly
  sharedVars = import ../shared-variables.nix;
in
{
  environment.sessionVariables = sharedVars.baseEnvironment // {
    # Force override for Qt platform theme to align with system default
    QT_QPA_PLATFORMTHEME = lib.mkForce "qt5ct";
  };

  # Create a custom sudo wrapper that points to the setuid wrapper
  environment.systemPackages = [
    (pkgs.writeShellScriptBin "sudo" ''
      exec /run/wrappers/bin/sudo "$@"
    '')
  ];
}
