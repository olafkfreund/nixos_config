{ pkgs
, ...
}: {
  environment.systemPackages = [
    pkgs.wayvnc
  ];
}
