{
  inputs,
  pkgs,
  config,
  pkgs-stable,
  ...
}: {
  home.packages = with pkgs-stable; [
    azure-cli
    azure-storage-azcopy
    kubelogin
    powershell
    sqlcmd
    blobfuse
    rsync
    #Python packages needed by ansible
    python311Packages.azure-mgmt-authorization
    python311Packages.azure-mgmt-apimanagement
    python311Packages.azure-mgmt-batch
    python311Packages.azure-mgmt-cdn
    python311Packages.azure-mgmt-compute
    python311Packages.azure-mgmt-containerinstance
    python311Packages.azure-mgmt-core
    python311Packages.azure-mgmt-containerregistry
    python311Packages.azure-mgmt-containerservice
    python311Packages.azure-mgmt-datalake-store
    python311Packages.azure-mgmt-datafactory
    python311Packages.azure-mgmt-dns
    python311Packages.azure-mgmt-marketplaceordering
    python311Packages.azure-mgmt-monitor
    python311Packages.azure-mgmt-managedservices
    python311Packages.azure-mgmt-managementgroups
    python311Packages.azure-mgmt-network
    python311Packages.azure-mgmt-nspkg
    python311Packages.azure-mgmt-privatedns
    python311Packages.azure-mgmt-redis
    python311Packages.azure-mgmt-resource
    python311Packages.azure-mgmt-rdbms
    python311Packages.azure-mgmt-search
    python311Packages.azure-mgmt-search
    python311Packages.azure-mgmt-sql
    python311Packages.azure-mgmt-storage
    python311Packages.azure-mgmt-trafficmanager
    python311Packages.azure-mgmt-web
    python311Packages.azure-storage-blob
    python311Packages.azure-keyvault
    python311Packages.azure-mgmt-keyvault
    python311Packages.azure-mgmt-cosmosdb
    python311Packages.azure-mgmt-hdinsight
    python311Packages.azure-mgmt-devtestlabs
    python311Packages.azure-mgmt-loganalytics
    #python311Packages.azure-mgmt-automation
    python311Packages.azure-mgmt-iothub
    #python311Packages.azure-iot-hub
    python311Packages.azure-mgmt-recoveryservices
    python311Packages.azure-mgmt-recoveryservicesbackup
    python311Packages.azure-mgmt-notificationhubs
    python311Packages.azure-mgmt-eventhub
    python311Packages.azure-containerregistry
    python311Packages.msgraph-core
    python311Packages.xmltodict
    python311Packages.jmespath
    python311Packages.packaging
    python311Packages.ansible
    python311Packages.ansible-compat
    python311Packages.setuptools
    python311Packages.msrestazure
    python311Packages.virtualenv
    # azure extensions
    azure-cli-extensions.fzf # fuzzy finder
    azure-cli-extensions.k8s-extension # k8s extensions
    azure-cli-extensions.terraform # terraform
    azure-cli-extensions.bastion
  ];
}
