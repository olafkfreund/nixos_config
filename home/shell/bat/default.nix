{ pkgs, ... }: { 
  programs.bat = {
    enable = true;
    config = {
      # theme = "gruvbox-dark";
      style = "numbers,changes";
    };
    extraPackages = with pkgs.bat-extras; [
      prettybat
      batman
      batdiff
    ];
  };
}
