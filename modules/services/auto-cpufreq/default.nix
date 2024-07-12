{ self, config, pkgs, ... }: {
  services.auto-cpufreq = {
    enable = false;
    settings = {
      battery = {
         governor = "powersave";
         turbo = "never";
      };
      charger = {
         governor = "performance";
         turbo = "auto";
      };
    };
  };
}
