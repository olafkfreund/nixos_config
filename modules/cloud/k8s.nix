{ config
, lib
, pkgs
, ...
}:
with lib; let
  cfg = config.k8s.packages;
in
{
  options.k8s.packages = {
    enable = mkEnableOption "Enable k8s packages";
  };
  config = mkIf cfg.enable {
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
  };
}
