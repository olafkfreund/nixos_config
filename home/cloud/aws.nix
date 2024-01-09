{ pkgs, ... }: {
  home.packages = with pkgs; [
    # aws
    awscli2
    awsrm
    awsls
    awsume
    awslogs
    aws-mfa
    aws-vault
    aws-rotate-key
    bash-my-aws
    terraforming
    aws-iam-authenticator
    eksctl
    istioctl
    aws-vault
   ];
}
