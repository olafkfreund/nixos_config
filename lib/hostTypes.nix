# Host Type Templates
# Provides standard import lists for different host types
# Eliminates duplicate import statements across host configurations
let
  desktopTemplate = profile: import ../hosts/templates/desktop.nix { inherit profile; };
in
{
  # Workstation configuration (P620, P510 - powerful desktop systems)
  workstation.imports = [ (desktopTemplate "workstation") ];

  # Laptop configuration (Razer - portable system with power management)
  laptop.imports = [ (desktopTemplate "laptop") ];
}
