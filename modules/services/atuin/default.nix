{ pkgs, ... }: {
  services.atuin = {
    enable = true;
    package = pkgs.atuin;
  };
}
