{ pkgs
, ...
}: {
  environment.systemPackages = [
    pkgs.waypipe
    pkgs.wayvnc
  ];
}
