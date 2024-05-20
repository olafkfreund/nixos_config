{ self, config, pkgs, ... }: {

services.auto-cpufreq = {
  enable = true;
  };
}