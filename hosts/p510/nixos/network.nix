{ config
, lib
, pkgs
, ...
}: {
  # Network interface configuration for P510
  # Primary interface: eno1 (onboard Intel I218-LM)
  # Additional interfaces: ens6f0, ens6f1 (Intel 82571EB dual-port card)

  # NetworkManager requires resolved to be disabled for its own DNS management
  services.resolved.enable = lib.mkForce false;

  # Use NetworkManager for easier configuration
  networking = {
    # Use NetworkManager instead of systemd-networkd for simplicity
    networkmanager.enable = true;
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

  # Enable network interface bonding if needed (commented out by default)
  # This would bond the two new interfaces for redundancy or increased throughput
  # networking.bonds = {
  #   bond0 = {
  #     interfaces = [ "ens6f0" "ens6f1" ];
  #     driverOptions = {
  #       mode = "active-backup";  # or "802.3ad" for LACP
  #       miimon = "100";
  #       primary = "ens6f0";
  #     };
  #   };
  # };

  # Enable VLANs if needed (commented out by default)
  # networking.vlans = {
  #   vlan100 = {
  #     id = 100;
  #     interface = "ens6f0";
  #   };
  #   vlan200 = {
  #     id = 200;
  #     interface = "ens6f1";
  #   };
  # };

  # Firewall configuration for the new interfaces
  networking.firewall = {
    # Allow specific services on the new interfaces
    interfaces = {
      ens6f0 = {
        # Storage/Backup network - allow NFS, SMB, etc.
        allowedTCPPorts = [
          111 # NFS portmapper
          2049 # NFS
          445 # SMB
          22 # SSH for backup operations
        ];
        allowedUDPPorts = [
          111 # NFS portmapper
          2049 # NFS
        ];
      };

      ens6f1 = {
        # Management network - allow management protocols
        allowedTCPPorts = [
          22 # SSH
          443 # HTTPS for web management
          623 # IPMI
        ];
        allowedUDPPorts = [
          623 # IPMI
        ];
      };
    };
  };
}
