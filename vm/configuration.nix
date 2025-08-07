{ lib
, pkgs
, isImageTarget
, ...
}: {
  imports = lib.optionals (!isImageTarget) [
    ./hardware-configuration.nix
    ./disko-config.nix
  ];

  # Enable X server and Plasma 6 desktop environment
  services.desktopManager.plasma6.enable = true;

  # Enable SDDM
  services.displayManager.sddm.enable = true;

  # Define the "nixos" user
  users.users.nixos = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ]; # "wheel" for sudo, "networkmanager" for networking
    initialPassword = "nixos"; # Default password (changeable on first login)
  };

  # Allow passwordless sudo for the "wheel" group
  security.sudo.wheelNeedsPassword = false;

  # Install essential packages
  environment.systemPackages = with pkgs; [
    brave
    vlc
  ];

  # Enable networking with NetworkManager
  networking.networkmanager.enable = true;

  # Set the time zone (optional)
  time.timeZone = "UTC";

  # Specify the system state version
  system.stateVersion = "25.05";
}
