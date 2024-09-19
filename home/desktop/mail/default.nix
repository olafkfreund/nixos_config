{ pkgs, ... }: {
  
  home.packages = with pkgs; [
    birdtray
    thunderbird
  ];

  programs.thunderbird = {
    enable = true;
  };
}
