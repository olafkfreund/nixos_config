{ config
, pkgs
, microvm
, ...
}: {
  microvm = rec {
    vms =
      builtins.mapAttrs
        (name: type:
          if type != "directory"
          then abort "invalid guest: ${name}"
          else {
            inherit pkgs;
            config = pkgs.mmell.lib.builders.mk-microvm (import (./guests + "/${name}"));
          })
        (builtins.readDir ./guests);
    autostart = builtins.attrNames vms;
  };
}
