# Nixi fleet board (#168): the hosts that report to it, and the token they share.
# `nixiFleet` is the one list; 11b reads it for services.nixi-status and the
# home-manager peers (edit it here, not there). A member decrypts the token:
# companion hosts read it as the user, p510 (no companion) only as root.
{ config, ... }:
let
  nixiFleet = [
    {
      name = "p620";
      address = "100.69.100.115";
      companion = true;
    }
    {
      name = "p510";
      address = "100.118.96.32";
      companion = false;
    }
    {
      name = "razer";
      address = "100.90.72.124";
      companion = true;
    }
  ];
  me = builtins.filter (h: h.name == config.networking.hostName) nixiFleet;
in
{
  age.secrets = builtins.listToAttrs (
    map
      (h: {
        name = "nixi-status-token";
        value = {
          file = ../../../secrets/nixi-status-token.age;
          owner = if h.companion then "olafkfreund" else "root";
          mode = "0400";
        };
      })
      me
  );
}
