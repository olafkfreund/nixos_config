{ pkgs, ... }: {
  
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

  system.activationScripts.binbash = {
    deps = [ "binsh" ];
    text = ''
         ln -s /bin/sh /bin/bash
    '';
  };
}
