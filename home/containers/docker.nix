{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    docker-compose
    nvidia-docker
   ];

  #Docker config
  virtualisation.docker.enable = true;
  virtualisation.docker.rootless = {
    enable = true;
    setSocketVariable = true;
  };
  programs = {
    };
}
