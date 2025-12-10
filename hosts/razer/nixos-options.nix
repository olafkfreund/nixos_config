{ lib, ... }: {
  aws.packages.enable = true;
  azure.packages.enable = true; # Re-enabled Azure CLI
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
  programs.lazygit.enable = lib.mkForce true;
  programs.thunderbird.enable = lib.mkForce true;
  programs.obsidian.enable = lib.mkForce true;
  programs.office.enable = lib.mkForce true;
  programs.webcam.enable = lib.mkForce true;

  # Virtualization tools
  services.docker.enable = lib.mkForce true;
  services.incus.enable = lib.mkForce true;
  services.podman.enable = lib.mkForce true;
  services.spice.enable = lib.mkForce true;
  services.libvirt.enable = lib.mkForce true;

  # Password management
  security.onepassword.enable = lib.mkForce true;
  security.gnupg.enable = lib.mkForce true;

  # VPN
  vpn.tailscale.enable = lib.mkForce true;

  # AI (Ollama disabled on mobile hosts for resource optimization - Issue #67)
  ai.ollama.enable = lib.mkForce false;

  # Printing
  services.print.enable = lib.mkForce true;
}
