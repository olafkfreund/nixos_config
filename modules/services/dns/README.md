# Secure DNS for NixOS

This module enables DNS over TLS (DoT) or HTTPS (DoH) in NixOS using systemd-resolved, providing encrypted DNS lookups to enhance privacy and security.

## Features

- DNS over TLS (DoT) support
- DNSSEC validation
- Integration with systemd-networkd and NetworkManager
- Configurable DNS providers
- Simple activation through module options

## Usage

Enable secure DNS in your host configuration:

```nix
{
  # Enable secure DNS with DNS over TLS
  services.secure-dns = {
    enable = true;
    dnssec = "true";  # Can be "true", "false", or "allow-downgrade"
    
    # Configure your preferred DNS providers
    fallbackProviders = [
      "1.1.1.1#cloudflare-dns.com"  # Cloudflare
      "8.8.8.8#dns.google"          # Google
      "9.9.9.9#dns.quad9.net"       # Quad9 (filtered for security)
    ];
    
    # Whether to point system nameservers to systemd-resolved's stub resolver
    useStubResolver = true;
  };
}
```

## How It Works

The module configures systemd-resolved to use DNS over TLS for all queries. It sets up:

1. The systemd-resolved service with DoT enabled
2. The stub resolver (127.0.0.53) as the system DNS server
3. DNSSEC validation for added security
4. Integration with your existing network configuration

## Verifying It's Working

After enabling the module and rebuilding your system, you can verify that DNS over TLS is working with:

```bash
# Check systemd-resolved status
resolvectl status

# Test a DNS lookup 
resolvectl query nixos.org
```

You should see "YES" under the "DNSOverTLS" column in the resolvectl output.

## Troubleshooting

If DNS resolution isn't working:

1. Check if systemd-resolved is running: `systemctl status systemd-resolved`
2. Verify your network settings: `resolvectl status`
3. Make sure your firewall allows outgoing connections on port 853 (DoT)
4. Check logs for errors: `journalctl -u systemd-resolved -f`

## DNS Provider Options

Here are some popular DNS providers that support DoT:

| Provider | IP Address | DoT Hostname |
|----------|------------|-------------|
| Cloudflare | 1.1.1.1 | cloudflare-dns.com |
| Google | 8.8.8.8 | dns.google |
| Quad9 | 9.9.9.9 | dns.quad9.net |
| AdGuard | 94.140.14.14 | dns.adguard.com |
| CleanBrowsing | 185.228.168.168 | security-filter-dns.cleanbrowsing.org |

## Further Customization

For more advanced configurations, refer to the [systemd-resolved documentation](https://www.freedesktop.org/software/systemd/man/resolved.conf.html).