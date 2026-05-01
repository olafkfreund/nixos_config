{ config
, lib
, pkgs
, pkgs-stable
, ...
}:
let
  inherit (lib) mkEnableOption mkIf mkMerge;
in
{
  options = {
    aws.packages.enable = mkEnableOption "Enable AWS packages";
    azure.packages.enable = mkEnableOption "Enable Azure packages";
    cloud-tools.packages.enable = mkEnableOption "Enable cloud tools";
    google.packages.enable = mkEnableOption "Enable Google packages";
    k8s.packages.enable = mkEnableOption "Enable k8s packages";
    terraform.packages.enable = mkEnableOption "Enable terraform packages";
  };

  config = mkMerge [
    (mkIf config.aws.packages.enable {
      environment.systemPackages = [
        pkgs-stable.awscli2
        pkgs.awsrm
        pkgs.awsls
        pkgs.awsume
        pkgs.awslogs
        pkgs.aws-mfa
        pkgs.aws-vault
        pkgs.aws-rotate-key
        pkgs.terraforming
        pkgs.aws-iam-authenticator
        pkgs.eksctl
        pkgs.istioctl
      ];
    })

    (mkIf config.azure.packages.enable {
      environment.systemPackages = with pkgs; [
        azure-cli
        azure-storage-azcopy
        kubelogin
        powershell
        sqlcmd
        blobfuse
        rsync
        dotnetCorePackages.sdk_9_0
        # Python packages for Azure management
        python312Packages.azure-mgmt-authorization
        python312Packages.azure-mgmt-apimanagement
        python312Packages.azure-mgmt-batch
        python312Packages.azure-mgmt-cdn
        python312Packages.azure-mgmt-compute
        python312Packages.azure-mgmt-containerinstance
        python312Packages.azure-mgmt-core
        python312Packages.azure-mgmt-containerregistry
        python312Packages.azure-mgmt-containerservice
        python312Packages.azure-mgmt-datalake-store
        python312Packages.azure-mgmt-datafactory
        python312Packages.azure-mgmt-dns
        python312Packages.azure-mgmt-marketplaceordering
        python312Packages.azure-mgmt-monitor
        python312Packages.azure-mgmt-managedservices
        python312Packages.azure-mgmt-managementgroups
        python312Packages.azure-mgmt-network
        python312Packages.azure-mgmt-nspkg
        python312Packages.azure-mgmt-privatedns
        python312Packages.azure-mgmt-redis
        python312Packages.azure-mgmt-resource
        python312Packages.azure-mgmt-rdbms
        python312Packages.azure-mgmt-search
        python312Packages.azure-mgmt-search
        python312Packages.azure-mgmt-sql
        python312Packages.azure-mgmt-storage
        python312Packages.azure-mgmt-trafficmanager
        python312Packages.azure-mgmt-web
        python312Packages.azure-storage-blob
        python312Packages.azure-keyvault
        python312Packages.azure-mgmt-keyvault
        python312Packages.azure-mgmt-cosmosdb
        python312Packages.azure-mgmt-hdinsight
        python312Packages.azure-mgmt-devtestlabs
        python312Packages.azure-mgmt-loganalytics
        python312Packages.azure-mgmt-iothub
        python312Packages.azure-mgmt-recoveryservices
        python312Packages.azure-mgmt-recoveryservicesbackup
        python312Packages.azure-mgmt-notificationhubs
        python312Packages.azure-mgmt-eventhub
        python312Packages.azure-containerregistry
        python312Packages.msgraph-core
        python312Packages.xmltodict
        python312Packages.jmespath
        python312Packages.packaging
        python312Packages.setuptools
        python312Packages.msrestazure
        python312Packages.virtualenv
        # azure extensions
        azure-cli-extensions.fzf
        azure-cli-extensions.k8s-extension
        azure-cli-extensions.bastion
        yamllint
      ];
    })

    (mkIf config.cloud-tools.packages.enable {
      environment.systemPackages = with pkgs; [
        teller
        yq-go
        ytt
      ];
    })

    (mkIf config.google.packages.enable {
      environment.systemPackages = with pkgs; [
        google-cloud-sdk
      ];
    })

    (mkIf config.k8s.packages.enable {
      environment.systemPackages = with pkgs; [
        kubectl
        tubekit
        krelay
        tfk8s
        kubectl-explore
        kubernetes-helm
        kubecolor
        k9s
        kops
        kubectx
        k8sgpt
        kubetail
      ];
    })

    (mkIf config.terraform.packages.enable {
      environment.systemPackages = [
        pkgs.terraform
        pkgs.terraformer
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
        pkgs.terrascan
        pkgs.terranix
      ];
    })
  ];
}
