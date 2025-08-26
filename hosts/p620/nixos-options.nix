{ lib, ... }: {
  aws.packages.enable = true;
  # azure.packages.enable = true; # Temporarily disabled due to msgraph-core build failure
  cloud-tools.packages.enable = true;
  google.packages.enable = true;
  k8s.packages.enable = true;
  # openshift.packages.enable = true;
  terraform.packages.enable = true;

  # Development tools
  ansible.development.enable = true;
  cargo.development.enable = true;
  github.development.enable = true;
  go.development.enable = true;
  java.development.enable = true;
  lua.development.enable = true;
  nix.development.enable = true;
  shell.development.enable = true;
  devshell.development.enable = true;
  python.development.enable = true;
  nodejs.development.enable = true;

  # Git tools
  programs = {
    lazygit.enable = lib.mkForce true;
    thunderbird.enable = lib.mkForce true;
    obsidian.enable = lib.mkForce true;
    office.enable = lib.mkForce true;
    webcam.enable = lib.mkForce true;
  };

  # Virtualization tools and services
  services = {
    docker.enable = lib.mkForce true;
    incus.enable = lib.mkForce true;
    podman.enable = lib.mkForce true;
    spice.enable = lib.mkForce true;
    libvirt.enable = lib.mkForce true;
    print.enable = lib.mkForce true;
  };

  # Password management
  security = {
    onepassword.enable = lib.mkForce true;
    gnupg.enable = lib.mkForce true;
  };

  # VPN
  vpn.tailscale.enable = lib.mkForce true;

  # AI
  ai.ollama.enable = lib.mkForce true;
}
