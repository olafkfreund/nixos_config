{ pkgs, ...}: {
  environment.systemPackages = [
    pkgs.wldash
  ];
}
