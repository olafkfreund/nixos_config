_:
let
  vars = import ../variables.nix;
in
{
  environment.sessionVariables = vars.environmentVariables;
}
