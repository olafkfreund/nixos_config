{ config
, lib
, pkgs
, pkgs-stable
, ...
}:
with lib; let
  cfg = config.aws.packages;
in
{
  options.aws.packages = {
    enable = mkEnableOption "Enable AWS packages";
  };
  config = mkIf cfg.enable {
    environment.systemPackages = [
      pkgs-stable.awscli2
      pkgs.awsrm
      pkgs.awsls
      pkgs.awsume
      pkgs.awslogs
      pkgs.aws-mfa
      pkgs.aws-vault
      pkgs.aws-rotate-key
      pkgs.terraforming
      pkgs.aws-iam-authenticator
      pkgs.eksctl
      pkgs.istioctl
    ];
  };
}
