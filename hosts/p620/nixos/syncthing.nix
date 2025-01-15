{
  lib,
  config,
  pkgs,
  pkgs-unstable,
  ...
}: {
  services.syncthing = {
    settings = {
      devices = {
        "razer" = {id = "DEVICE-ID-GOES-HERE";};
        "p620" = {id = "DEVICE-ID-GOES-HERE";};
      };
      folders = {
        "Documents" = {
          path = "/home/olafkfreund/Documents";
          devices = ["razer" "p620"];
        };
        "Source" = {
          path = "/home/olafkfreund/Source";
          devices = ["razer" "p620"]; # This folder is shared with both devices.
          # By default, Syncthing doesn't sync file permissions. This line enables it for this folder.
          ignorePerms = false;
        };
      };
    };
  };
}
