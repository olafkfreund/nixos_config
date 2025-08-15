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

  # Fix PATH ordering at systemd level (fixes sudo setuid issue)
  # This ensures /run/wrappers/bin comes before /run/current-system/sw/bin
  systemd.settings.Manager.DefaultEnvironment = [
    "PATH=/run/wrappers/bin:/run/current-system/sw/bin:/nix/var/nix/profiles/default/bin"
  ];

  # Also create environment.d file for system-wide PATH fix
  environment.etc."environment.d/99-sudo-path-fix.conf".text = ''
    PATH=/run/wrappers/bin:/run/current-system/sw/bin:/nix/var/nix/profiles/default/bin
  '';
}
