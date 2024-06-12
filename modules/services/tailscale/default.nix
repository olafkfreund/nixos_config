{ self, config, pkgs, ... }: {

  services.tailscale = {
    enable = true;
  };

  environment.systemPackages = [
    pkgs.trayscale
    pkgs.ktailctl
  ];
}
