{...}: {
  imports = [
    ./imports.nix
    ./base-home.nix
    ./features.nix
    # Temporarily disabled for isolated enhanced desktop test
    # ./features-impl.nix
  ];
}
