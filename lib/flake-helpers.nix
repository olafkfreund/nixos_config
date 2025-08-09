# Helper functions for modern flake architecture
{ lib, nixpkgs }:

with lib;

rec {
  # Create a system-specific package set with our overlays
  mkPkgs = system: overlays: import nixpkgs {
    inherit system overlays;
    config = {
      allowUnfree = true;
      # SECURITY: Remove global allowInsecure - let individual systems specify permittedInsecurePackages
      # allowInsecure = true; # REMOVED for security
      
      # Default permitted insecure packages that are commonly needed
      permittedInsecurePackages = [
        "olm-3.2.16"
        "python3.12-youtube-dl-2021.12.17"
      ];
    };
  };

  # Helper to create shell environments for all systems
  mkShells = { systems ? [ "x86_64-linux" ], shells }: 
    genAttrs systems (system:
      let
        pkgs = mkPkgs system [];
      in
      mapAttrs (_: shell: shell { inherit pkgs; }) shells
    );

  # Helper to create checks for all systems
  mkChecks = { systems ? [ "x86_64-linux" ], checks }:
    genAttrs systems (system:
      let
        pkgs = mkPkgs system [];
      in
      mapAttrs (_: check: check { inherit pkgs; }) checks
    );

  # Helper to create packages for all systems  
  mkPackages = { systems ? [ "x86_64-linux" ], packages }:
    genAttrs systems (system:
      let
        pkgs = mkPkgs system [];
      in
      mapAttrs (_: package: package { inherit pkgs; }) packages
    );

  # Helper to create applications for all systems
  mkApps = { systems ? [ "x86_64-linux" ], apps }:
    genAttrs systems (system:
      let
        pkgs = mkPkgs system [];
      in
      mapAttrs (_: app: {
        type = "app";
        program = "${app { inherit pkgs; }}";
      }) apps
    );

  # Validate host configuration exists
  validateHost = host: hostUsers:
    if hasAttr host hostUsers
    then hostUsers.${host}
    else throw "Host '${host}' not found in hostUsers configuration";

  # Get supported systems (currently just x86_64-linux)
  supportedSystems = [ "x86_64-linux" ];

  # Flake-utils compatible forAllSystems
  forAllSystems = f: genAttrs supportedSystems (system: f system);
}