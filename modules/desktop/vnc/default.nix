{
  pkgs,
  pkgs-stable,
  ...
}: {
  environment.systemPackages = [
    pkgs.wayvnc
  ];
}
