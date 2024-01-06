{ config, pkgs, nixpkgs, ... }: {


  # -----------------------------------------------------------------
  #   Set your time zone.
  # -----------------------------------------------------------------
  time.timeZone = "Europe/London";

  # time.ntpServers = [
  #   "0.nixos.pool.ntp.org"
  #   "1.nixos.pool.ntp.org"
  #   "2.nixos.pool.ntp.org"
  #   "3.nixos.pool.ntp.org"
  #   "time.google.com"
  #   "time2.google.com"
  #   "time3.google.com"
  #   "time4.google.com"
  # ];

  i18n.defaultLocale = "en_GB.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_GB.UTF-8";
    LC_IDENTIFICATION = "en_GB.UTF-8";
    LC_MEASUREMENT = "en_GB.UTF-8";
    LC_MONETARY = "en_GB.UTF-8";
    LC_NAME = "en_GB.UTF-8";
    LC_NUMERIC = "en_GB.UTF-8";
    LC_PAPER = "en_GB.UTF-8";
    LC_TELEPHONE = "en_GB.UTF-8";
    LC_TIME = "en_GB.UTF-8";
  };
  console.keyMap = "uk";

  services.xserver = {
    layout = "gb";
    xkbVariant = "";
  };
}
