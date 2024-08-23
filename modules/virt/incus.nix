{
  pkgs,
  ...
}: {
  virtualisation = {
    incus = {
      package = pkgs.incus;
      enable = true;
    };
  };
  virtualisation.incus.ui.enable = true;
}

