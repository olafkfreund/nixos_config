{
  pkgs,
  config,
  inputs,
  nix-colors,
  ...
}: {
  programs.swaylock = {
    enable = true;
    settings = {
<<<<<<< HEAD
      # image = "$HOME/Pictures/wallpapers/gruvbox/hypr/pc_gruvbox_nologo.png";
      # color = "504945";
      # inside-color = "89b482";
      # font = "JetBrainsMono Nerd Font Medium";
=======
      image = "$HOME/Pictures/wallpapers/gruvbox/hypr/pc_gruvbox_nologo.png";
      color = "504945";
      inside-color = "89b482";
      font = "JetBrainsMono Nerd Font Medium";
>>>>>>> 6f826e2188d86f7d0c76929d56e6cedb6863fd9d
      font-size = 24;
      indicator-idle-visible = false;
      indicator-radius = 100;
      # key-hl-color = "a9b665";
      # bs-hl-color = "ea6962";
      # line-color = "ebdbb2";
      # ring-color = "7daea3";
      # ring-clear-color = "bd6f3e";
      # inside-clear-color = "ea6962";
      # ring-caps-lock-color = "e78a4e";
      # ring-ver-color = "7daea3";
      # inside-ver-color = "7daea3";
      # text-ver-color = "fbf1c7";
      # text-clear-color = "2a2827";
      # ring-wrong-color = "ea6962";
      # inside-wrong-color = "ea6962";
      # separator-color = "5a524c";
      show-failed-attempts = true;
    };
  };
}
