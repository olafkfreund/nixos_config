{ ... }: {
  # Overlays for P620-specific package overrides
  # nixpkgs.overlays = [
  #   (final: prev: {
  #     microsoft-identity-broker = prev.microsoft-identity-broker.overrideAttrs (oldAttrs: {
  #       src = pkgs.fetchurl {
  #         url = "https://packages.microsoft.com/ubuntu/22.04/prod/pool/main/m/microsoft-identity-broker/microsoft-identity-broker_2.0.1_amd64.deb";
  #         sha256 = "18z75zxamp7ss04yqwhclnmv3hjxrkb4r43880zwz9psqjwkm11";
  #       };
  #     });
  #   })
  # ];
}
