{
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    azure-cli
    azure-storage-azcopy
    kubelogin
    powershell
    sqlcmd
    blobfuse
   ];
}
