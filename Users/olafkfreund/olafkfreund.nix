{ config, pkgs, stdenv, lib, attrs, ... }:

#---------------------------------------------------------------------
# olafkfreund Erok
# 10/6/2023
# My personal NIXOS KDE user configuration 
# ¯\_(ツ)_/¯
#---------------------------------------------------------------------

{
  imports = [

  ];

  #---------------------------------------------------------------------
  # Set your time zone.
  #---------------------------------------------------------------------
  time.timeZone = "Europe/London";

  #---------------------------------------------------------------------
  # Select internationalisation properties.
  #---------------------------------------------------------------------
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

  #---------------------------------------------------------------------
  # Configure keymap in X11
  #---------------------------------------------------------------------
  services.xserver = {
    layout = "gb";
    xkbVariant = "";
  };

  #---------------------------------------------------------------------
  # User Configuration
  #---------------------------------------------------------------------
  users.users.olafkfreund = {
    # group = "olafkfreund";
    createHome = true;
    description = "Olaf K-Freund";
    home = "/home/olafkfreund/";
    homeMode = "0755";
    isNormalUser = true;
    uid = 1000;

    extraGroups = [
      "adbusers"
      "audio"
      "corectrl"
      "disk"
      "docker"
      "input"
      "libvirtd"
      "lp"
      "minidlna"
      "mongodb"
      "mysql"
      "network"
      "networkmanager"
      "postgres"
      "power"
      "samba"
      "scanner"
      "smb"
      "sound"
      "storage"
      "systemd-journal"
      "udev"
      "users"
      "video"
      "wheel" # Enable ‘sudo’ for the user.
    ];

    packages = [ pkgs.home-manager ];

    #---------------------------------------------------------------------
    # Create new password => mkpasswd -m sha-512
    #---------------------------------------------------------------------
    hashedPassword =
      "$6$Wf5DwaaVHNUU3Ucy$J5m9qAsl6S0t5V6GsBl7epzMTRVo/dr0YrDcFJP2ZhWNcJKsVcu7dwhh8iHPH/G4UlDUX07MgjjaBwnsU3RaR0";

    openssh.authorizedKeys.keys = [
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDQdhOoJ2wZCXRqU0BjbsVJYXXLp7RtAwY0KYBWcYREvPlo3u6Epge1oOUq69GU752pNCxEXsuG4u2pE20cziJ8ti8u5OGbbpMaHMGlGQPfXXZlIq21ZhJo0se5Im4isH/yfjo+/fXlpXywN2/zPTOrbzDrW23pq1KBh0QUwsr2Bq8sQBjo4Al0hT+qwlqfNcmPh3EBjabbyaNVkRxB27VIhnOKEshS/N9SQC1Olw67BrvVxFgHUZt5pP3h/eaGzJAud09GHXz9Ff8e6wX9ePjiF+zk3q5SgU6hrlobYPRasVu72VrmVPIw8CyCeCT8iRjfUgaDl8F8LWKOEWOas6goAtNk+zaTLqPM74qWh4TU8pbJ9UcUyCjzylUzpZH0KFIDwTkS38kAC+WWMS1ih4OVA7oelN0M0DEvkKQLAGTX/EJdrtLWeYiieTmt8sTxK5YAeBafO9uJXXMp0bwtkkYw4GkANdxilUtya5w4yZtapsZ6n+bIBcTIC5e2TQJ9Pc8= olafkfreund@fedoraolaffreund"
    ];

    openssh.authorizedKeys.keyFiles = [
      /home/olafkfreund/.ssh/id_rsa.pub

    ];

  };

  services.cron = {
    enable = true;
    systemCronJobs = [
      "0,5,10,15,20,25,30,35,40,45,50,55 * * * * root sh /home/olafkfreund/Desktop/none.sh"
    ];
  };

}
