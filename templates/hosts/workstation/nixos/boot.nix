# Boot configuration for workstation template
{ config, pkgs, ... }:

{
  # Bootloader configuration
  boot.loader = {
    systemd-boot = {
      enable = true;
      configurationLimit = 10; # Keep last 10 generations
      editor = false; # Disable editor for security
    };
    efi = {
      canTouchEfiVariables = true;
      efiSysMountPoint = "/boot";
    };
    timeout = 3; # Boot timeout in seconds
  };

  # Alternative: GRUB configuration (uncomment if preferred)
  # boot.loader = {
  #   grub = {
  #     enable = true;
  #     device = "nodev";
  #     efiSupport = true;
  #     configurationLimit = 10;
  #   };
  #   efi.canTouchEfiVariables = true;
  # };

  # Kernel selection
  boot.kernelPackages = pkgs.linuxPackages_latest; # Use latest kernel
  # Alternative: LTS kernel for stability
  # boot.kernelPackages = pkgs.linuxPackages;

  # Boot optimization
  boot.kernelParams = [
    "quiet" # Quiet boot
    "splash" # Show splash screen
    "rd.systemd.show_status=false" # Hide systemd status
    "rd.udev.log_level=3" # Reduce udev log level
    "udev.log_priority=3" # Reduce udev log priority
  ];

  # Performance optimizations
  boot.kernel.sysctl = {
    # Network performance
    "net.core.rmem_max" = 268435456;
    "net.core.wmem_max" = 268435456;
    "net.ipv4.tcp_rmem" = "4096 65536 268435456";
    "net.ipv4.tcp_wmem" = "4096 65536 268435456";
    "net.ipv4.tcp_congestion_control" = "bbr";

    # File system performance
    "vm.swappiness" = 10; # Reduce swap usage
    "vm.dirty_ratio" = 15; # Improve disk I/O
    "vm.dirty_background_ratio" = 5;

    # Memory management
    "vm.max_map_count" = 2147483642; # Increase for applications like games

    # Security hardening (optional)
    "kernel.dmesg_restrict" = 1;
    "kernel.kptr_restrict" = 2;
    "net.ipv4.conf.all.log_martians" = 1;
    "net.ipv4.conf.default.log_martians" = 1;
  };

  # Tmpfs for /tmp (performance improvement)
  boot.tmp = {
    useTmpfs = true;
    tmpfsSize = "50%"; # Use up to 50% of RAM for /tmp
  };

  # Boot splash configuration
  boot.plymouth = {
    enable = true;
    theme = "breeze";
  };

  # Console configuration
  console = {
    earlySetup = true;
    font = "Lat2-Terminus16";
  };

  # Hardware support
  hardware.enableAllFirmware = true;
  hardware.enableRedistributableFirmware = true;

  # Module blacklist (add problematic modules here)
  boot.blacklistedKernelModules = [
    # Example: "pcspkr"  # Disable PC speaker
  ];

  # Extra kernel modules to load
  boot.extraModulePackages = with config.boot.kernelPackages; [
    # Add extra modules here if needed
  ];

  # Initrd configuration
  boot.initrd = {
    supportedFilesystems = [ "ext4" "vfat" "xfs" "btrfs" ];

    # Network support in initrd (for remote unlocking)
    network = {
      enable = false; # Set to true if you need network in initrd
      # ssh = {
      #   enable = true;
      #   port = 2222;
      #   hostKeys = [ "/etc/secrets/initrd/ssh_host_rsa_key" ];
      # };
    };
  };

  # Hibernation support (optional)
  # boot.resumeDevice = "/dev/disk/by-uuid/YOUR-SWAP-UUID";

  # Custom boot entries (optional)
  # boot.loader.systemd-boot.extraEntries = {
  #   "windows.conf" = ''
  #     title Windows
  #     efi /EFI/Microsoft/Boot/bootmgfw.efi
  #   '';
  # };
}
