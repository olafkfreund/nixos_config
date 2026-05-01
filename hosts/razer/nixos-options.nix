_: {
  aws.packages.enable = true;
  azure.packages.enable = true; # Re-enabled Azure CLI
  cloud-tools.packages.enable = true;
  google.packages.enable = true;
  k8s.packages.enable = true;
  # openshift.packages.enable = true;
  terraform.packages.enable = true;

  # Development tools
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
  programs.lazygit.enable = true;
  programs.thunderbird.enable = false;
  programs.obsidian.enable = true;
  programs.office.enable = true;
  programs.webcam.enable = true;

  # Virtualization tools
  services.docker.enable = true;
  services.incus.enable = true;
  services.podman.enable = true;
  services.spice.enable = true;
  services.libvirt.enable = true;

  # Password management
  security.onepassword.enable = true;
  security.gnupg.enable = true;

  # VPN
  vpn.tailscale.enable = true;

  # AI providers configured in configuration.nix

  # Printing
  services.print.enable = true;
}
