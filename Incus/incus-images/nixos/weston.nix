# config/weston.nix
{ config, pkgs, ... }:

{
  services.weston = {
    enable = true;
    user = "botchi";
    display = ":99";
    virtualDisplay = true;
    config = ''
      [core]
      modules=systemd-notify.so
     
     [screen-share]
      command=weston --backend=rdp-backend.so --shell=fullscreen-shell.so --rdp-tls-cert=/etc/freerdp/keys/server.crt --rdp-tls-key=/etc/freerdp/keys/server.key --no-clients-resize start-on-startup=true 
    '';
  };
}
