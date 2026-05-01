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
  programs = {
    lazygit.enable = true;
    thunderbird.enable = false;
    obsidian.enable = true;
    office.enable = true;
    webcam.enable = true; # OBS Virtual Camera support
  };

  # Virtualization tools and services
  services = {
    docker.enable = true;
    incus.enable = true;
    podman.enable = true;
    spice.enable = true;
    libvirt.enable = true;
    print.enable = true;
  };

  # Password management
  security = {
    onepassword.enable = true;
    gnupg.enable = true;
  };

  # VPN
  vpn.tailscale.enable = true;

  # AI providers configured in configuration.nix
}
