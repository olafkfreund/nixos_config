{
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    # aws
    awscli2
    aws-iam-authenticator
    eksctl
    istioctl
    aws-vault
   ];
}
