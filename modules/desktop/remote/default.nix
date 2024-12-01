{
  pkgs,
  pkgs-stable,
  ...
}: {
  environment.systemPackages = [
    pkgs.waypipe
    pkgs.wayvnc
  ];
}
