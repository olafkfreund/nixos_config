{
  pkgs,
  ...
}: {
  environment.systemPackages = with pkgs; [
    kubectl
    kubernetes-helm
	  kubecolor
	  k9s
  ];
}
