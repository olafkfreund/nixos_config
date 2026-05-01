# Library functions and utilities
{ lib
, ...
}:
let
  inherit (lib) makeExtensible;

  # Import all library modules
  modules = {
    mkModule = import ./mkModule.nix;
    features = import ./features.nix;
    validation = import ./validation.nix;
    secrets = import ./secrets.nix;
  };
in
makeExtensible (self:
modules
  // {
  # Utility functions
  inherit (lib) mkIf mkOption mkEnableOption types;

  # Custom utility functions
  mkFeatureModule = name: config: self.mkModule { inherit lib; } name config;

  # Import helpers
  importModules = path:
    builtins.filter (f: f != null) (
      map
        (
          f:
          let
            fullPath = path + "/${f}";
          in
          if builtins.pathExists fullPath && lib.hasSuffix ".nix" f
          then fullPath
          else null
        )
        (builtins.attrNames (builtins.readDir path))
    );
})
