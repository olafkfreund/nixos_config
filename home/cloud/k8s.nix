{ pkgs, ... }: {
  home.packages = with pkgs; [
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
}

