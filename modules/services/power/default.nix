{ pkgs, config, inputs, ... }: {

  services.power-profiles-daemon = {
    enable = false;
  };
}