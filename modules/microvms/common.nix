# Common MicroVM Configuration
{ config, lib, pkgs, ... }:
with lib; let
  cfg = config.features.microvms;
in {
  options.features.microvms = {
    enable = mkEnableOption "MicroVM support";
    
    dev-vm.enable = mkEnableOption "Development MicroVM";
    test-vm.enable = mkEnableOption "Testing MicroVM";
    playground-vm.enable = mkEnableOption "Playground MicroVM";
    
    storageRoot = mkOption {
      type = types.str;
      default = "/var/lib/microvms";
      description = "Root directory for MicroVM persistent storage";
    };
    
    sharedRoot = mkOption {
      type = types.str;
      default = "/tmp/microvm-shared";
      description = "Root directory for shared storage between host and VMs";
    };
  };

  config = mkIf cfg.enable {
    # Enable MicroVM support on the host
    virtualisation.libvirtd.enable = true;
    
    # Create storage directories
    systemd.tmpfiles.rules = [
      "d ${cfg.storageRoot} 0755 root root -"
      "d ${cfg.storageRoot}/dev-vm 0755 root root -"
      "d ${cfg.storageRoot}/test-vm 0755 root root -"
      "d ${cfg.storageRoot}/playground-vm 0755 root root -"
      "d ${cfg.sharedRoot} 0755 root root -"
    ];
    
    # Install microvm management tools
    environment.systemPackages = with pkgs; [
      qemu_kvm
      socat
    ];
    
    # Enable KVM for better performance
    boot.kernelModules = [ "kvm-intel" "kvm-amd" ];
    
    # Firewall rules for MicroVM SSH access
    networking.firewall = {
      allowedTCPPorts = [ 2222 2223 2224 ];  # SSH ports for VMs
      allowedTCPPortRanges = [
        { from = 8080; to = 8090; }  # Web development ports
      ];
    };
    
    # User groups for MicroVM management
    users.groups.microvm = {};
    users.users.${config.users.users.olafkfreund.name or "olafkfreund"}.extraGroups = [ "microvm" "libvirtd" ];
  };
}