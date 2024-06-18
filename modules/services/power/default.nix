{ pkgs, config, inputs, ... }: {

  services.power-profiles-daemon = {
    enable = false;
  };
  services = {
    undervolt = {
        tempBat = 65; # deg C
        package = pkgs.undervolt;
      };
    };
    
  powerManagement = {
    powertop = {
      enable = false;
    };
  };
}
