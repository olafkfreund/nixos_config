{ pkgs, config, inputs, ... }: {
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
