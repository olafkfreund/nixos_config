
{ pkgs, lib, ... }: {

  home.packages = with pkgs; [
    git
    gitui
    git-credential-oauth
    git-credential-manager
    lazygit
    onefetch
  ];
  programs.git = {
    enable = true;
    aliases = {
      ci = "commit";
      co = "checkout";
      s = "status";
    };
    userName = "Olaf K-Freund";
    userEmail = lib.mkForce "olaf.loken@gmail.com";
    extraConfig.init.defaultBranch = "main";
  };
}
