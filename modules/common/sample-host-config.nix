{
  pkgs,
  lib,
  inputs,
  ...
}: {
  # Import your hardware-specific modules and other necessities
  imports = [
    # ./nixos/hardware-configuration.nix
    # ./nixos/power.nix
    # ./nixos/boot.nix
    # ... other hardware-specific imports
  ];

  # Set hostname
  networking.hostName = "hostname";

  # Choose networking profile: "desktop", "server", or "minimal"
  networking.profile = "server";

  # Enable development features using the new system
  features = {
    development = {
      enable = true; # Enable development tools in general

      # Enable specific development environments
      ansible = false;
      cargo = true;
      github = true;
      go = true;
      java = false;
      lua = true;
      nix = true;
      shell = true;
      devshell = true;
      python = true;
      nodejs = true;
    };

    virtualization = {
      enable = true; # Enable virtualization tools in general

      # Enable specific virtualization technologies
      docker = true;
      incus = false;
      podman = true;
      spice = true;
      libvirt = true;
      sunshine = true;
    };

    cloud = {
      enable = true; # Enable cloud tools in general

      # Enable specific cloud provider tools
      aws = false;
      azure = false;
      google = false;
      k8s = false;
      terraform = false;
    };

    security = {
      enable = true;
      onepassword = true;
      gnupg = true;
    };

    networking = {
      enable = true;
      tailscale = true;
    };

    ai = {
      enable = true;
      ollama = false;
    };

    programs = {
      lazygit = true;
      thunderbird = false;
      obsidian = false;
      office = false;
      webcam = false;
      print = false;
    };

    media = {
      droidcam = true;
    };
  };

  # Add any host-specific configuration below
  # ...
}
