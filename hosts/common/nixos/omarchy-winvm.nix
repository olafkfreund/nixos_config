# The nixarchy-winvm repo is the plugin directory itself.
{ inputs, ... }:
{
  home-manager.users.olafkfreund.programs.nixarchy.plugins."nixarchy.winvm".src =
    inputs.nixarchy-winvm;
}
