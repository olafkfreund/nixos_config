{
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    lunarvim
  ];
}
