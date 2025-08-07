{
  pkgs,
  ...
}: let
  ipv4 = "5.78.43.185";
  fqdn2domain = "infra.holochain.org";
in {
  system.activationScripts.bind-zones.text = ''
    mkdir -p /etc/bind/zones
    chown named:named /etc/bind/zones
  '';

  environment.etc."bind/zones/${fqdn2domain}.zone" = {
    enable = true;
    user = "named";
    group = "named";
    mode = "0644";
    text = ''
      $ORIGIN .
      $TTL 60 ; 1 minute
      ${fqdn2domain} IN SOA ns1.${fqdn2domain}. admin.holochain.org. (
                                        2001062504 ; serial
                                        21600      ; refresh (6 hours)
                                        3600       ; retry (1 hour)
                                        604800     ; expire (1 week)
                                        86400      ; minimum (1 day)
                                      )

                              NS      ns1.${fqdn2domain}.
      $ORIGIN ${fqdn2domain}.
      ns1                                      A       ${ipv4}
      ${fqdn2domain}.                          A       ${ipv4}

      *.${fqdn2domain}.                        CNAME   ${fqdn2domain}.

      testing.events.${fqdn2domain}.           A       127.0.0.1
      hackathons.events.${fqdn2domain}.        A       10.1.3.37
      hackathon.events.${fqdn2domain}.         A       10.1.3.37
      amsterdam2023.events.${fqdn2domain}.     A       10.1.3.187

      sj-bm-hostkey0.dev.${fqdn2domain}.       A       185.130.224.33
    '';
  };

  services.bind = {
    enable = true;
    extraConfig = ''
      include "/var/lib/secrets/*-dnskeys.conf";
    '';
    zones = [
      {
        name = fqdn2domain;
        allowQuery = ["any"];
        file = "/etc/bind/zones/${fqdn2domain}.zone";
        master = true;
        extraConfig = "allow-update { key rfc2136key.${fqdn2domain}.; };";
      }
    ];
  };

  systemd.services.dns-rfc2136-2-conf = let
    dnskeysConfPath = "/var/lib/secrets/${fqdn2domain}-dnskeys.conf";
    dnskeysSecretPath = "/var/lib/secrets/${fqdn2domain}-dnskeys.secret";
  in {
    requiredBy = ["acme-${fqdn2domain}.service" "bind.service"];
    before = ["acme-${fqdn2domain}.service" "bind.service"];
    unitConfig = {
      ConditionPathExists = "!${dnskeysConfPath}";
    };
    serviceConfig = {
      Type = "oneshot";
      UMask = 0077;
    };
    path = [pkgs.bind];
    script = ''
      mkdir -p /var/lib/secrets
      chmod 755 /var/lib/secrets
      tsig-keygen rfc2136key.${fqdn2domain} > ${dnskeysConfPath}
      chown named:root ${dnskeysConfPath}
      chmod 400 ${dnskeysConfPath}

      # extract secret value from the dnskeys.conf
      while read x y; do if [ "$x" = "secret" ]; then secret="''${y:1:''${#y}-3}"; fi; done < ${dnskeysConfPath}

      cat > ${dnskeysSecretPath} << EOF
      RFC2136_NAMESERVER='127.0.0.1:53'
      RFC2136_TSIG_ALGORITHM='hmac-sha256.'
      RFC2136_TSIG_KEY='rfc2136key.${fqdn2domain}'
      RFC2136_TSIG_SECRET='$secret'
      EOF
      chmod 400 ${dnskeysSecretPath}
    '';
  };
}
