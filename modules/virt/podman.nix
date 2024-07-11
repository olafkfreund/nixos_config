{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    #nvidia-podman
    podman-compose
    podman-tui
    podman-desktop
    podman
    pods
    libceph
    ceph
   ];
  virtualisation = {
    podman = {
    enable = true;
    #dockerCompat = true;
    defaultNetwork.settings.dns_enabled = true;
    };
  };
  #virtualisation.podman.dockerSocket.enable = true;
}
