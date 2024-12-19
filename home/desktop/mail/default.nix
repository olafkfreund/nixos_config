{
  pkgs,
  pkgs-unstable,
  ...
}: {
  home.packages = with pkgs-unstable; [
    birdtray
    thunderbird-latest
  ];

  programs.thunderbird = {
    enable = true;
  };
}
