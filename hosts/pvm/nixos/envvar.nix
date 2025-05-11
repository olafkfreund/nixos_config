{
  self,
  config,
  pkgs,
  ...
}: {
  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    NIXPKGS_ALLOW_INSECURE = "1";
    NIXPKGS_ALLOW_UNFREE = "1";
  };
}
