# Consolidated hosts.nix - used by all hosts
# Converts shared host mappings to /etc/hosts entries
{ ... }:
let
  # Import shared variables directly (works for all hosts since they use same shared-variables.nix)
  sharedVars = import ../shared-variables.nix;

  # Convert the host mappings attrset to a string
  # Format: "ip hostname"
  hostsString = with builtins;
    if (sharedVars.network ? hostMappings && sharedVars.network.hostMappings != { }) then
      concatStringsSep "\n" (
        attrValues (mapAttrs (ip: hostname: "${ip} ${hostname}") sharedVars.network.hostMappings)
      )
    else "";
in
{
  networking.extraHosts = hostsString;
}
