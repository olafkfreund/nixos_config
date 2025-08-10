{ lib, ... }:
let
  vars = import ../variables.nix { inherit lib; };
in
{
  environment.sessionVariables = vars.environmentVariables;
}
