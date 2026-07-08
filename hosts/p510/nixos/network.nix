{ lib
, ...
}: {
  # Network interface configuration for P510
  # Primary interface: eno1 (onboard Intel I218-LM)
  # Additional interfaces: ens6f0, ens6f1 (Intel 82571EB dual-port card)

  # Enable systemd-resolved for DNS resolution with NetworkManager
  services.resolved.enable = true;

  # Use NetworkManager for easier configuration
  networking = {
    # Use NetworkManager instead of systemd-networkd for simplicity
    networkmanager = {
      enable = true;
      dns = lib.mkForce "systemd-resolved"; # Use systemd-resolved for DNS
    };
    useNetworkd = lib.mkForce false;

    # Configure network interfaces - use DHCP for now, can configure static IPs via NetworkManager later
    interfaces = {
      # Primary interface (already configured via DHCP by default)
      eno1 = {
        useDHCP = true;
      };

      # First port of the dual-port Intel card - for future use (Storage/Backup Network)
      ens6f0 = {
        useDHCP = true; # Leave unconfigured for now
      };

      # Second port of the dual-port Intel card - for future use (Management/IPMI Network)
      ens6f1 = {
        useDHCP = true; # Leave unconfigured for now
      };
    };
  };
}
