{ pkgs, ... }: {
  services.thermald.enable = true;
  services.upower.enable = true;
  services.power-profiles-daemon.enable = true;
  services.auto-cpufreq = {
    enable = false;
    settings = {
      battery = {
        governor = "powersave";
        turbo = "auto";
      };
      charger = {
        governor = "performance";
        turbo = "auto";
      };
    };
  };

  environment.systemPackages = with pkgs; [
    cpupower-gui
    powertop # only use it to check current power usage
    lm_sensors
  ];

  systemd = {
    targets = {
      sleep = {
        enable = false;
        unitConfig.DefaultDependencies = "no";
      };
      suspend = {
        enable = false;
        unitConfig.DefaultDependencies = "no";
      };
      hibernate = {
        enable = false;
        unitConfig.DefaultDependencies = "no";
      };
      "hybrid-sleep" = {
        enable = false;
        unitConfig.DefaultDependencies = "no";
      };
    };
  };
}
