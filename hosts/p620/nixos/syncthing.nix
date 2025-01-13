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
        "device1" = {id = "DEVICE-ID-GOES-HERE";};
        "device2" = {id = "DEVICE-ID-GOES-HERE";};
      };
      folders = {
        "Documents" = {
          path = "/home/myusername/Documents";
          devices = ["device1" "device2"];
        };
        "Example" = {
          path = "/home/myusername/Example";
          devices = ["device1"];
          # By default, Syncthing doesn't sync file permissions. This line enables it for this folder.
          ignorePerms = false;
        };
      };
    };
  };
}
