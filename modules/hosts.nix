{ config, pkgs, ... }:

{ networking.extraHosts = ''
  10.198.1.10  dev.digitaldirham.gov.ae
'';
}
