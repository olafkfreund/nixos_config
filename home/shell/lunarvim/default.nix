{
  pkgs,
  pkgs-stable,
  ...
}: {
  home.packages = with pkgs; [
    lunarvim
  ];
}
