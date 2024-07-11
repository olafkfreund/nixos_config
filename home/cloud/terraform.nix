{ pkgs
  ,pkgs-stable
, ...
}: {
  home.packages = [
    pkgs.terraform
    pkgs.terraformer
    pkgs.terraform-docs
    pkgs.tftui
    pkgs.terraform-providers.digitalocean
    pkgs.terraform-providers.oci
    pkgs.terraform-providers.ssh
    pkgs.terraform-providers.lxd
    pkgs.terraform-providers.aws
    pkgs.terraform-providers.age
    pkgs.terraform-providers.sops
    pkgs.terraform-providers.acme
    pkgs.terraform-providers.local
    pkgs.terraform-providers.google
    pkgs.terraform-providers.github
    pkgs.terraform-providers.libvirt
    pkgs.terraform-providers.kubectl
    pkgs.terraform-providers.azurerm
    pkgs.terraform-providers.azuread
    pkgs.terraform-providers.linuxbox
    pkgs.terraform-providers.tailscale
    pkgs.terraform-providers.openstack
    pkgs.terraform-providers.kubernetes
    pkgs.terraform-providers.digitalocean
    pkgs-stable.checkov
    pkgs.terrascan
    pkgs.terranix # terrafrom by nix
  ];
}
