{ pkgs, self, ...}: {
  
    services.flameshot = {
    enable = true;
    package = pkgs.flameshot.override { enableWlrSupport = true; };
  };
}
