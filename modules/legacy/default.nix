{...}: {
  imports = [
    # Import legacy modules that haven't been refactored yet
    # These modules maintain backward compatibility during transition

    # Legacy system modules
    ../common
    ../system

    # Legacy application modules
    ../office
    ../fonts

    # Legacy development modules
    ../nix

    # Legacy networking modules
    ../ssh

    # Legacy utility modules
    ../system-scripts
    ../system-utils
    ../system-tweaks

    # Legacy hardware modules
    ../laptop-related
    ../webcam

    # Legacy service modules
    ../spell

    # Legacy container modules (will be moved to virtualization)
    ../containers

    # Legacy packages
    ../pkgs
    ../overlays
  ];
}
