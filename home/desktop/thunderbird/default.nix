{ ... }: {
  programs.thunderbird = {
    enable = true;
    package = pkgs.thunderbird;
  };
}
