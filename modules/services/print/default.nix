{ config
, lib
, pkgs
, ...
}:
let
  inherit (lib) mkIf mkEnableOption;
  username = "olafkfreund";
  cfg = config.services.print;

  # Override SANE packages to use GCC 14 for compatibility (GCC 15 fails on old C code)
  sane-frontends-gcc14 = pkgs.sane-frontends.override {
    stdenv = pkgs.gcc14Stdenv;
  };
  xsane-gcc14 = pkgs.xsane.override {
    sane-frontends = sane-frontends-gcc14;
    stdenv = pkgs.gcc14Stdenv;
  };
in
{
  options.services.print = {
    enable = mkEnableOption {
      default = false;
      description = "Enable the HP print service";
    };
  };
  config = mkIf cfg.enable {
    services = {
      printing.enable = true;
      avahi = {
        enable = true;
        nssmdns4 = true;
        nssmdns6 = true;
        openFirewall = true;
        settings = {
          server = {
            use-ipv4 = true;
            use-ipv6 = true;
          };
          publish = {
            disable-publishing = false;
            publish-addresses = true;
            publish-workstation = true;
            disable-user-service-publishing = false;
          };
        };
        # nixpkgs' ipp-usb module still sets these obsolete options, which warn on
        # every build; their effect is stated in settings.publish above.
        publish.enable = lib.mkForce null;
        publish.userServices = lib.mkForce null;
      };
      ipp-usb.enable = true;
    };
    hardware.sane = {
      enable = true;
      extraBackends = [ pkgs.hplip ];
      disabledDefaultBackends = [ "escl" ];
    };
    services.printing.drivers = [ pkgs.hplip ];
    programs.system-config-printer.enable = true;
    users.users.${username}.extraGroups = [ "scanner" "lp" ];
    environment.systemPackages = [
      pkgs.hplip
      xsane-gcc14 # Using GCC 14 override for compatibility
      pkgs.sane-airscan
      pkgs.simple-scan
      pkgs.system-config-printer
      pkgs.ghostscript
      pkgs.cups
      pkgs.gawk
    ];
  };
}
