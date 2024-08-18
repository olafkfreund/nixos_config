{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    podman-compose
    podman-tui
    podman-desktop
    podman
    pods
   ];
  virtualisation = {
    podman = {
    enable = true;
    defaultNetwork.settings.dns_enabled = true;
    };
  };
}
