{
  pkgs,
  pkgs-stable,
  config,
  lib,
  ...
}:
with lib; let
  cfg = config.azure.packages;
in {
  options.azure.packages = {
    enable = mkEnableOption "Enable Azure packages";
  };
  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      azure-cli
      azure-storage-azcopy
      kubelogin
      powershell
      sqlcmd
      blobfuse
      rsync
      dotnetCorePackages.sdk_9_0
      #Python packages needed by ansible
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
      #python312Packages.azure-mgmt-automation
      python312Packages.azure-mgmt-iothub
      #python312Packages.azure-iot-hub
      python312Packages.azure-mgmt-recoveryservices
      python312Packages.azure-mgmt-recoveryservicesbackup
      python312Packages.azure-mgmt-notificationhubs
      python312Packages.azure-mgmt-eventhub
      python312Packages.azure-containerregistry
      python312Packages.msgraph-core
      python312Packages.xmltodict
      python312Packages.jmespath
      python312Packages.packaging
      python312Packages.ansible
      python312Packages.ansible-compat
      python312Packages.setuptools
      python312Packages.msrestazure
      python312Packages.virtualenv
      # azure extensions
      azure-cli-extensions.fzf # fuzzy finder
      azure-cli-extensions.k8s-extension # k8s extensions
      azure-cli-extensions.bastion
    ];
  };
}
