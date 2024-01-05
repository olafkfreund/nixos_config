{ config, pkgs, options, lib, ... }:

#---------------------------------------------------------------------
# My personal NIXOS KDE configuration 
# 
#   ███▄    █     ██▓   ▒██   ██▒    ▒█████       ██████ 
#   ██ ▀█   █    ▓██▒   ▒▒ █ █ ▒░   ▒██▒  ██▒   ▒██    ▒ 
#  ▓██  ▀█ ██▒   ▒██▒   ░░  █   ░   ▒██░  ██▒   ░ ▓██▄   
#  ▓██▒  ▐▌██▒   ░██░    ░ █ █ ▒    ▒██   ██░     ▒   ██▒
#  ▒██░   ▓██░   ░██░   ▒██▒ ▒██▒   ░ ████▓▒░   ▒██████▒▒
#  ░ ▒░   ▒ ▒    ░▓     ▒▒ ░ ░▓ ░   ░ ▒░▒░▒░    ▒ ▒▓▒ ▒ ░
#  ░ ░░   ░ ▒░    ▒ ░   ░░   ░▒ ░     ░ ▒ ▒░    ░ ░▒  ░ ░
#     ░   ░ ░     ▒ ░    ░    ░     ░ ░ ░ ▒     ░  ░  ░  
#           ░     ░      ░    ░         ░ ░           ░  
# 
#---------------------------------------------------------------------

let
  
  # Auto HOST chooser based on device product name
  # Terminal:   cat /sys/devices/virtual/dmi/id/product_name or product_sku
  #---------------------------------------------------------------------
  importfile = ( if builtins.readFile "/sys/devices/virtual/dmi/id/product_family" == "ThinkPad X1 Extreme Gen 5\n" then
    ./hosts/work-lx/configuration.nix

    else if builtins.readFile "/sys/devices/virtual/dmi/id/product_name" == "Blade 15 Advanced Model (Early 2021) - RZ09-036\n" then
      ./hosts/razer/configuration.nix
  
  else

    # Manually symlink host/machine
    # ---------------------------------------------
    ./hosts/manual/config.nix

  );

in

{
  imports = [ 
    
    # call attribute thats declared above
    # ---------------------------------------------
    importfile 
    
    # KDE config
    # ---------------------------------------------
    ./modules/xserver.nix
    
  ];

}
