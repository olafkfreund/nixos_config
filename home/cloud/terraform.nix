{ pkgs
, ...
}: {
  home.packages = with pkgs; [
    terraform
    terraformer
    terraform-docs
    tftui
    terraform-providers.digitalocean
    terraform-providers.oci
    terraform-providers.ssh
    terraform-providers.lxd
    terraform-providers.aws
    terraform-providers.age
    terraform-providers.sops
    terraform-providers.acme
    terraform-providers.local
    terraform-providers.google
    terraform-providers.github
    terraform-providers.libvirt
    terraform-providers.kubectl
    terraform-providers.azurerm
    terraform-providers.azuread
    terraform-providers.linuxbox
    terraform-providers.tailscale
    terraform-providers.openstack
    terraform-providers.kubernetes
    terraform-providers.digitalocean
    checkov
    terrascan
    terranix # terrafrom by nix
  ];
}
