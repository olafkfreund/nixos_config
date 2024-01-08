{ self, config, pkgs, ... }:

{
  imports =
    [ 
      ./hardware-configuration.nix
      ./boot.nix
      ../../modules/system-tweaks/storage-tweaks/SSD/SSD-tweak.nix
      ../../modules/system-tweaks/kernel-tweaks/32GB-SYSTEM/32GB-SYSTEM.nix
      ../../modules/laptop-related/autorandr.nix
      ../../modules/laptop-related/earlyoom.nix
      ../../modules/laptop-related/zram.nix
      ../../modules/default.nix
      ../../home/containers/default.nix
      ../../modules/default.nix
      ../../home/containers/default.nix
      ../../modules/services/thinkpad/thinkpad.nix
			./nvidia.nix
			./i18n.nix
      ./envvar.nix
    ];

networking.hostName = "work-lx"; # Define your hostname.
networking.networkmanager.enable = true;

# Define a user account. Don't forget to set a password with ‘passwd’.
users.users.olafkfreund = {
  isNormalUser = true;
  description = "Olaf K-Freund";
  extraGroups = [ "networkmanager" "wheel" "docker" ];
  packages = with pkgs; [
    kate
    kitty
    neovim
    vim
  ];
};

environment.systemPackages = with pkgs; [
 	wget
 	git
 	curl
 	file
	lsof
	lshw
	openssl
	ripgrep
	tcpdump
	tree
	unzip
	which
	gcc
	gdb
	go
	gnumake
	ispell
	aspell
	jq
	sqlite
	z3
];
security.sudo.wheelNeedsPassword = false;
networking.firewall.enable = false;
system.stateVersion = "23.11"; # Did you read the comment?

}
