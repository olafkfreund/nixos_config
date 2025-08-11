_: {
  services = {
    gvfs.enable = true;
    udisks2.enable = true;
    devmon.enable = true;
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
