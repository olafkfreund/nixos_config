# Example configuration for secure DNS
# Import this file or copy these settings into your host configuration
{
  config,
  pkgs,
  ...
}: {
  # Enable secure DNS with DNS over TLS
  services.secure-dns = {
    enable = true;
    dnssec = "true"; # Enable DNSSEC validation

    # You can customize the DNS providers if needed
    fallbackProviders = [
      "1.1.1.1#cloudflare-dns.com" # Cloudflare DNS
      "8.8.8.8#dns.google" # Google DNS
      "9.9.9.9#dns.quad9.net" # Quad9 (filtered for security)
    ];

    useStubResolver = true; # Use systemd-resolved's stub resolver
  };

  # If you need to disable NetworkManager's DNS management
  # networking.networkmanager.dns = "systemd-resolved";
}
