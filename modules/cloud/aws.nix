{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.aws.packages;
in {
  options.aws.packages = {
    enable = mkEnableOption "Enable AWS packages";
  };
  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
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
  };
}
