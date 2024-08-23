{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    minikube
    kind
  ];
}
