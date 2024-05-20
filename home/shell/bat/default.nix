{ pkgs, ... }: { 
  programs.bat = {
    enable = true;
    config = {
<<<<<<< HEAD
      # theme = "gruvbox-dark";
=======
      theme = "gruvbox-dark";
>>>>>>> 6f826e2188d86f7d0c76929d56e6cedb6863fd9d
      style = "numbers,changes";
    };
    extraPackages = with pkgs.bat-extras; [
      prettybat
      batman
      batdiff
    ];
  };
<<<<<<< HEAD
}
=======
}
>>>>>>> 6f826e2188d86f7d0c76929d56e6cedb6863fd9d
