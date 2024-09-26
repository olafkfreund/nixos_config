{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.security.intune-portal;
in {
  options.security.intune-portal = {
    enable = mkEnableOption {
      default = false;
      description = "Microsoft Intune Portal";
    };
  };
  config = mkIf cfg.enable {
    services.intune = {
      enable = true;
    };
    environment.systemPackages = [
      pkgs.microsoft-identity-broker
    ];

    nixpkgs.overlays = [
      (final: prev: {
        microsoft-identity-broker = prev.microsoft-identity-broker.overrideAttrs (previousAttrs: {
          src = pkgs.fetchurl {
            url = "https://packages.microsoft.com/ubuntu/22.04/prod/pool/main/m/microsoft-identity-broker/microsoft-identity-broker_2.0.1_amd64.deb";
            sha256 = "18z75zxamp7ss04yqwhclnmv3hjxrkb4r43880zwz9psqjwkm113";
          };
        });
      })
    ];
  };
}
