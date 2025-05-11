{
  self,
  config,
  pkgs,
  ...
}: let
  vars = import ../variables.nix;
in {
  environment.sessionVariables = vars.environmentVariables;
}
