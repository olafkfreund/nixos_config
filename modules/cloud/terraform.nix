{ config
, lib
, pkgs
, ...
}:
with lib; let
  cfg = config.terraform.packages;
in
{
  options.terraform.packages = {
    enable = mkEnableOption "Enable terraform packages";
  };
  config = mkIf cfg.enable {
    environment.systemPackages = [
      pkgs.terraform
      pkgs.terraformer
      # pkgs.terraform-docs
      pkgs.terraform-providers.digitalocean_digitalocean
      pkgs.terraform-providers.oracle_oci
      pkgs.terraform-providers.loafoe_ssh
      pkgs.terraform-providers.terraform-lxd_lxd
      pkgs.terraform-providers.hashicorp_aws
      pkgs.terraform-providers.clementblaise_age
      pkgs.terraform-providers.carlpett_sops
      pkgs.terraform-providers.vancluever_acme
      pkgs.terraform-providers.hashicorp_local
      pkgs.terraform-providers.hashicorp_google
      pkgs.terraform-providers.integrations_github
      pkgs.terraform-providers.dmacvicar_libvirt
      pkgs.terraform-providers.gavinbunney_kubectl
      pkgs.terraform-providers.hashicorp_azurerm
      pkgs.terraform-providers.hashicorp_azuread
      pkgs.terraform-providers.numtide_linuxbox
      pkgs.terraform-providers.tailscale_tailscale
      pkgs.terraform-providers.terraform-provider-openstack_openstack
      pkgs.terraform-providers.hashicorp_kubernetes
      # pkgs.checkov
      pkgs.terrascan
      pkgs.terranix # terrafrom by nix
    ];
  };
}
