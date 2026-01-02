_: {
  # Override udevil to use GCC 14 for compatibility (GCC 15 fails on old C code)
  nixpkgs.config.packageOverrides = prev: {
    udevil = prev.udevil.override {
      stdenv = prev.gcc14Stdenv;
    };
  };

  services = {
    gvfs.enable = true;
    udisks2.enable = true;
    devmon.enable = true; # Now works with GCC 14 override
    thermald.enable = true;
  };
  services.hardware.bolt = {
    enable = true;
  };

  system.activationScripts.binbash = {
    deps = [ "binsh" ];
    text = ''
      ln -sf /bin/sh /bin/bash
    '';
  };
}
