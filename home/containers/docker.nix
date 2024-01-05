{
  pkgs,
  ...
}: {
  environment.systemPackages = with pkgs; [
    docker-compose
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
