{ self, config, pkgs, ... }: {
  services.auto-cpufreq = {
    enable = true;
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
}
