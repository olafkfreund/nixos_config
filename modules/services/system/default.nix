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
  # services.resolved = {
  # enable = true;
  # dnssec = "true";
  # domains = [ "~." ];
  # # fallbackDns = [ "1.1.1.1#one.one.one.one" "1.0.0.1#one.one.one.one" ];
  # dnsovertls = "true";
  # };
  system.activationScripts.binbash = {
    deps = [ "binsh" ];
    text = ''
         ln -s /bin/sh /bin/bash
    '';
  };
}
