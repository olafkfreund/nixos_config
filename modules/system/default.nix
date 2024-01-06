{ config, pkgs, lib, attrs, ... }:
#---------------------------------------------------------------------
# Automatic system upgrades
#---------------------------------------------------------------------

let

  version = "23.11";
  # version = "23.11";

in {
  system = {
    autoUpgrade = {
      enable = true;
      allowReboot = false;
    };

    copySystemConfiguration = true;
    stateVersion = "${version}";

  };
}

