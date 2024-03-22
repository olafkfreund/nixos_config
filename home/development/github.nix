{ pkgs, ... }: {

home.packages = with pkgs; [
    act
    actionlint
    action-validator
    gitea-actions-runner
  ];
}
