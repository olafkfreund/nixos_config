{ pkgs, ... }: {

home.packages = with pkgs; [
  #vscode-fhs
  #vscode-extension-github-copilot
  #vscode-extension-github-copilot-chat
  #vscode-extension-redhat-vscode-xml
  #vscode-extension-jdinhlife-gruvbox
  #vscode-extension-redhat-vscode-yaml
  #vscode-extension-hashicorp-terraform
  #vscode-extension-ms-vscode-PowerShell
  #vscode-extension-ms-vscode-remote-remote-ssh
  #vscode-extension-ms-vscode-remote-remote-containers
  #vscode-extension-ms-kubernetes-tools-vscode-kubernetes-tools
  #vscode-extension-github-vscode-pull-request-github
];

programs.vscode = {
  enable = true;
  };
}
