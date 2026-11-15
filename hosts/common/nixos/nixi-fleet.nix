# Nixi fleet board (#168): the hosts that report to it, and the token they share.
# `nixiFleet` is the one list: it drives services.nixi-status (allowedCallers =
# the other companion hosts), the home-manager companion peers (every other
# host) and the shared token. A member decrypts the token: companion hosts read
# it as the user, p510 (no companion) only as root.
{ config
, inputs
, ...
}:
let
  fleet = import ../fleet.nix;
  nixiFleet = [
    {
      name = "p620";
      address = fleet.p620.tailnet;
      companion = true;
    }
    {
      name = "p510";
      address = fleet.p510.tailnet;
      companion = false;
    }
    {
      name = "razer";
      address = fleet.razer.tailnet;
      companion = true;
    }
  ];
  me = builtins.filter (h: h.name == config.networking.hostName) nixiFleet;
  others = h: builtins.filter (o: o.name != h.name) nixiFleet;
in
{
  imports = [ inputs.nixi-companion.nixosModules.status ];

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

  services.nixi-status = builtins.foldl'
    (_: h: {
      enable = true;
      inherit (h) address;
      allowedCallers = map (o: o.address) (builtins.filter (o: o.companion) (others h));
      tokenFile = config.age.secrets.nixi-status-token.path;
    })
    { }
    me;

  home-manager.users.olafkfreund.services.nixi.companion = builtins.foldl'
    (
      _: h:
        if h.companion then
          {
            peers = map (o: { inherit (o) name address; }) (others h);
            peerTokenFile = config.age.secrets.nixi-status-token.path;
          }
        else
          { }
    )
    { }
    me;
}
