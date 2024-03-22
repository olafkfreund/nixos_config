{ pkgs, config, lib, ... }: {

  services.atuin = {
    enable = true;
    package = pkgs.atuin;
  };
}
