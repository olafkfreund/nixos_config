# DEX5550 Home Configuration - Server Admin Profile
# Uses server-admin profile for headless server administration
{ lib, pkgs, config, ... }: {
  imports = [
    # Import common user configuration
    ../common/default.nix
    ./private.nix

    # Import server-admin profile
    ../../home/profiles/server-admin/default.nix

    # Host-specific environment
    ../../hosts/dex5550/nixos/env.nix
  ];

  # Profile metadata
  meta.profile = {
    name = "server-admin";
    type = "single";
    description = "Server administration profile for DEX5550";
    host = "dex5550";
  };

  # DEX5550-specific overrides
  # (Most configuration comes from server-admin profile)

  # Add DEX5550-specific packages if needed
  home.packages = with pkgs; [
    # Monitoring server specific tools
    prometheus
    grafana-cli
  ];
}
