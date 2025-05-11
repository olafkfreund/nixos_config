{
  pkgs,
  lib,
  inputs,
  username,
  ...
}: {
  imports = [
    ./nixos/hardware-configuration.nix
    ./nixos/i18n.nix
    ./nixos/hosts.nix
    ./nixos/envvar.nix
    ../../modules/default.nix
    ../../modules/development/default.nix
  ];

  # Set hostname
  networking.hostName = "pvm";

  # Choose networking profile: "server" for VM environment
  networking.profile = "server";

  # Use the new features system instead of multiple lib.mkForce calls
  features = {
    development = {
      enable = true;
      ansible = true;
      cargo = true;
      github = true;
      go = true;
      java = true;
      lua = true;
      nix = true;
      shell = true;
      devshell = true;
      python = true;
      nodejs = true;
    };

    virtualization = {
      enable = true;
      docker = true;
      podman = true;
    };

    cloud = {
      enable = true;
      aws = true;
      azure = true;
      google = true;
      k8s = true;
      terraform = true;
    };

    security = {
      enable = true;
      gnupg = true;
    };

    networking = {
      enable = true;
      tailscale = true;
    };

    ai = {
      enable = true;
      ollama = true;
    };
  };

  # Network configuration
  networking.nameservers = [
    "1.1.1.1"
    "8.8.8.8"
  ];

  # Disable wait-online services for faster boot
  systemd.services.NetworkManager-wait-online.enable = lib.mkForce false;
  systemd.services.systemd-networkd-wait-online.enable = lib.mkForce false;

  # Environment variables
  environment.sessionVariables = {
    NH_FLAKE = "/home/olafkfreund/.config/nixos";
  };

  # User configuration
  users.users.${username} = {
    isNormalUser = true;
    description = "Olaf K-Freund";
    extraGroups = ["wheel" "docker" "podman"];
    shell = pkgs.zsh;
    packages = with pkgs; [
      vim
    ];
  };

  # Service configuration
  services.playerctld.enable = true;
  services.fwupd.enable = true;
  services.ollama.acceleration = "cpu";

  nixpkgs.config.permittedInsecurePackages = ["olm-3.2.16"];
  system.stateVersion = "24.11";
}
