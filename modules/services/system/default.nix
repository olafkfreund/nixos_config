_: {
  services.gvfs = {
    enable = true;
  };
  services.udisks2 = {
    enable = true;
  };
  services.devmon = {
    enable = true;
  };
  services.thermald = {
    enable = true;
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
