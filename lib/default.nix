# Library functions and utilities
{ lib
, inputs
, ...
}:
let
  inherit (lib) makeExtensible;

  # Import all library modules
  modules = {
    mkModule = import ./mkModule.nix;
    features = import ./features.nix;
    hostTemplate = import ./hostTemplate.nix;
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

  # Host creation helper
  mkNixosHost = _hostName: config:
    let
      system = "x86_64-linux";
    in
    inputs.nixpkgs.lib.nixosSystem {
      inherit system;
      specialArgs = { inherit inputs lib system; };
      modules = [
        config
        ../modules
        self.features
        self.validation
        self.secrets
      ];
    };

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
