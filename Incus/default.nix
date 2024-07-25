{ pkgs, pkgs-stable, ... }:
{
  virtualisation.incus.preseed = {
    networks = [
      {
        config = {
          "ipv4.address" = "10.237.170.1/24";
          "ipv4.nat" = "true";
         "core.https_address" = ":8443"; 
        };
        name = "incusbr0";
        type = "bridge";
      }
    ];
    profiles = [
      {
        devices = {
          eth0 = {
            name = "eth0";
            network = "incusbr0";
            type = "nic";
          };
          root = {
            path = "/";
            pool = "default";
            size = "35GiB";
            type = "disk";
          };
        };
        name = "default";
      }
    ];
    storage_pools = [
      {
        config = {
          source = "/var/lib/incus/storage-pools/default";
        };
        driver = "dir";
        name = "default";
      }
    ];
  };
}
