{ pkgs, pkgs-stable, ... }: {
  home.packages = with pkgs-stable; [
    # aws
    awscli2
    awsrm
    awsls
    awsume
    awslogs
    aws-mfa
    aws-vault
    aws-rotate-key
    terraforming
    aws-iam-authenticator
    eksctl
    istioctl
    aws-vault
   ];
}
