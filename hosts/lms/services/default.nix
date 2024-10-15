{ pkgs, config, ... }:
let
  ipv4 = "192.168.0.35";
  fqdn2domain = "freundcloud.local";
in {
  services.nextcloud = {
    enable = true;
    https = true;
    hostName = "home.freundcloud.com";
    database.createLocally = true;
    appstoreEnable = true;
    enableImagemagick = true;
    autoUpdateApps.enable = true;
    settings = {
      trusted_domain = [ "192.168.0.35" "home.freundcloud.com" "home.freundcloud.local" ]; 
     } ;
    config = {
      dbtype = "pgsql";
      adminpassFile = "/etc/nextcloud.pass";
    };
    extraApps = {
    inherit (config.services.nextcloud.package.packages.apps) notes onlyoffice bookmarks deck contacts calendar tasks;
    };
    extraAppsEnable = true;
  };

services.nginx.virtualHosts.${config.services.nextcloud.hostName} = {
  forceSSL = true;
  enableACME = true;
};

security.acme = {
  certs = { 
    ${config.services.nextcloud.hostName}.email = "olaf@freundcloud.com"; 
  }; 
};

# services.jitsi-meet = {
#     enable = true;
#     hostName = "jitsi.freundcloud.com";
#     config = {
#       enableWelcomePage = false;
#       prejoinPageEnabled = true;
#       defaultLang = "en";
#     };
#     interfaceConfig = {
#       SHOW_JITSI_WATERMARK = false;
#       SHOW_WATERMARK_FOR_GUESTS = false;
#     };
# };
# services.jitsi-videobridge.openFirewall = true;
security.acme.email = "olaf@freundcloud.com";
security.acme.acceptTerms = true;

  networking.hosts = {
  "192.168.0.35" = [ "lms" "next.freundcloud.com" "home.freundcloud.com" ];
  };
  networking.firewall.allowedTCPPorts = [ 80 443 ];

  services.bind = {
    enable = true;
    forwarders = [ "1.1.1.1" "8.8.8.8" ];
    zones = [
      {
        name = fqdn2domain;
        allowQuery = ["any"];
        file = "/etc/bind/zones/${fqdn2domain}.zone";
        master = true;
      }
    ];
  };
}
