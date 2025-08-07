# Package sets interface for performance optimization
{ config
, lib
, pkgs
, ...
}:
with lib; let
  packageSets = import ./sets.nix { inherit pkgs lib; };
in
{
  options.packages = {
    sets = mkOption {
      type = types.anything;
      default = packageSets;
      description = "Consolidated package sets for improved performance";
      readOnly = true;
    };
  };

  config = {
    # Make package sets available globally
    _module.args.packageSets = packageSets;
  };
}
