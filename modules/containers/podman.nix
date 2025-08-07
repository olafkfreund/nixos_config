{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    podman-compose
    podman-tui
    podman-desktop
    podman
    virtiofsd
  ];
  virtualisation = {
    podman = {
      enable = true;
      defaultNetwork.settings.dns_enabled = true;
    };
  };
}
