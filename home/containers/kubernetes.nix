{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    kubectl
    tubekit
    krelay
    tfk8s
    kubectl-explore
    kubernetes-helm
	  kubecolor
	  k9s
  ];
}
