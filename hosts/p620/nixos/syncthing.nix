{
  ...
}: {
  services.syncthing = {
    settings = {
      devices = {
        "razer" = {id = "AKXAO57-DE2Z5DX-XE5DL6Y-MAIZTX7-ZKECOW6-LK23BXJ-NRUM6MU-VKGE2QQ";};
        "p620" = {id = " 22QAEJN-ITC3XKD-V6VS34N-EJL4ZOP-FRXTX2N-VSZBZJU-QYTDAWV-3QSENQK";};
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
