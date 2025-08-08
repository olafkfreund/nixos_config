_:
let
  vars = import ../variables.nix;

  # Convert the host mappings attrset to a string
  # Format: "ip hostname"
  hostsString = with builtins;
    concatStringsSep "\n" (
      attrValues (mapAttrs (ip: hostname: "${ip} ${hostname}") vars.hostMappings)
    );
in
{
  networking.extraHosts = hostsString;
}
