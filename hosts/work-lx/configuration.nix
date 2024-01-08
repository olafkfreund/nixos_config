{ self, config, pkgs, ... }:

{
  imports =
    [ 
    # Main core
    # ---------------------------------------------
			./hardware-configuration.nix
      ../../modules/default.nix
      
		# Custom System tweaks
    # ---------------------------------------------
			../../core/system-tweaks/storage-tweaks/SSD/SSD-tweak.nix
			../../core/system-tweaks/kernel-tweaks/32GB-SYSTEM/32GB-SYSTEM.nix
			../../core/system-tweaks/zram/zram-32GB-SYSTEM.nix
			../../core/laptop-related/autorandr.nix
		# Main HW
    # ---------------------------------------------
			./nvidia.nix
		# VIRT
    # ---------------------------------------------
			../../core/virt/virt.nix
			../../home/containers/default.nix
		# Locale
    # ---------------------------------------------
			../../locale/uk_english.nix
    ];

	networking.hostName = "work-lx"; # Define your hostname.
	networking.networkmanager.enable = true;

	# Define a user account. Don't forget to set a password with ‘passwd’.
	users.users.olafkfreund = {
		isNormalUser = true;
		description = "Olaf K-Freund";
		extraGroups = [ 
			"networkmanager" 
			"wheel" 
			"docker"
	  ];
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

	services.tp-auto-kbbl = {
  	enable = true;
  };
	services.thinkfan = {
		enable = true;
	};
	security.sudo.wheelNeedsPassword = false;
	networking.firewall.enable = false;
	system.stateVersion = "23.11"; # Did you read the comment?

}
