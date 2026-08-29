{ config
, lib
, pkgs
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
        pkgs.customPkgs.awscli2 # local override disables flaky doCheck
        pkgs.ssm-session-manager-plugin # `aws ssm start-session` (binary: session-manager-plugin)
        pkgs.awsrm
        pkgs.awsume
        pkgs.awslogs
        pkgs.aws-mfa
        pkgs.aws-vault
        pkgs.aws-rotate-key
        pkgs.terraforming
        pkgs.aws-iam-authenticator
      ];
    })

    (mkIf config.azure.packages.enable {
      environment.systemPackages = with pkgs; [
        azure-cli
        azure-storage-azcopy
        powershell
        sqlcmd
        blobfuse
        rsync
        dotnetCorePackages.sdk_9_0
        # Python packages for Azure management
        python3Packages.azure-mgmt-authorization
        python3Packages.azure-mgmt-apimanagement
        python3Packages.azure-mgmt-batch
        python3Packages.azure-mgmt-cdn
        python3Packages.azure-mgmt-compute
        python3Packages.azure-mgmt-containerinstance
        python3Packages.azure-mgmt-core
        python3Packages.azure-mgmt-containerregistry
        python3Packages.azure-mgmt-containerservice
        python3Packages.azure-mgmt-datalake-store
        python3Packages.azure-mgmt-datafactory
        python3Packages.azure-mgmt-dns
        python3Packages.azure-mgmt-marketplaceordering
        python3Packages.azure-mgmt-monitor
        python3Packages.azure-mgmt-managedservices
        python3Packages.azure-mgmt-managementgroups
        python3Packages.azure-mgmt-network
        python3Packages.azure-mgmt-nspkg
        python3Packages.azure-mgmt-privatedns
        python3Packages.azure-mgmt-redis
        python3Packages.azure-mgmt-resource
        python3Packages.azure-mgmt-rdbms
        python3Packages.azure-mgmt-search
        python3Packages.azure-mgmt-search
        python3Packages.azure-mgmt-sql
        python3Packages.azure-mgmt-storage
        python3Packages.azure-mgmt-trafficmanager
        python3Packages.azure-mgmt-web
        python3Packages.azure-storage-blob
        python3Packages.azure-keyvault
        python3Packages.azure-mgmt-keyvault
        python3Packages.azure-mgmt-cosmosdb
        python3Packages.azure-mgmt-hdinsight
        python3Packages.azure-mgmt-devtestlabs
        python3Packages.azure-mgmt-loganalytics
        python3Packages.azure-mgmt-iothub
        python3Packages.azure-mgmt-recoveryservices
        python3Packages.azure-mgmt-recoveryservicesbackup
        python3Packages.azure-mgmt-notificationhubs
        python3Packages.azure-mgmt-eventhub
        python3Packages.azure-containerregistry
        python3Packages.msgraph-core
        python3Packages.xmltodict
        python3Packages.jmespath
        python3Packages.packaging
        python3Packages.setuptools
        python3Packages.msrestazure
        python3Packages.virtualenv
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
        tfk8s
        kubernetes-helm
        kubecolor
        k9s
        kubectx
        kubetail
        # Local k8s clusters (moved from deleted modules/{virt,containers}/kubernetes.nix)
        minikube
        kind
      ];
    })

    (mkIf config.terraform.packages.enable {
      environment.systemPackages = [
        pkgs.terraform
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
        pkgs.terranix
      ];
    })
  ];
}
