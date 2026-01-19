# Microsoft Defender for Endpoint (MDE) for NixOS

Enterprise-grade endpoint detection and response security solution packaged for NixOS.

## Overview

This package provides Microsoft Defender for Endpoint for Linux systems running NixOS. It uses `buildFHSUserEnv` to create a Linux Standard Base (LSB) environment compatible with Microsoft's binary distribution.

## Package Information

- **Version**: 101.25102.0003-insiderfast (January 2025)
- **Channel**: insiders-fast (beta releases)
- **Size**: ~67MB (Debian package)
- **Architecture**: x86_64 only

## Prerequisites

### System Requirements

- **OS**: NixOS 24.05 or later
- **CPU**: x86_64 (64-bit)
- **Memory**: Minimum 1GB RAM (2GB+ recommended)
- **Disk**: 2GB free space
- **Network**: Internet connectivity to `*.endpoint.security.microsoft.com`

### Licensing Requirements

Microsoft Defender for Endpoint requires one of:

- Microsoft Defender for Endpoint subscription ($5-10/user/month)
- Microsoft Defender for Servers (included with Azure Defender)
- Microsoft 365 E5 or equivalent license

### Onboarding Requirements

1. Access to Microsoft Defender portal (<https://security.microsoft.com>)
2. Onboarding package downloaded from portal
3. Organizational ID for registration

## Installation

### Option 1: Add to NixOS Configuration

```nix
{ config, pkgs, ... }:

{
  # Add Microsoft Defender package
  environment.systemPackages = [
    (pkgs.callPackage ./pkgs/microsoft-defender-for-endpoint { })
  ];
}
```

### Option 2: Use NixOS Module (Recommended)

See `modules/services/security/mdatp.nix` for complete service integration.

```nix
{ config, pkgs, ... }:

{
  services.mdatp = {
    enable = true;
    onboardingFile = /path/to/WindowsDefenderATPOnboarding.json;
  };
}
```

## Usage

### Onboarding

1. **Download onboarding package** from Microsoft Defender portal:
   - Go to: Settings → Endpoints → Onboarding
   - Select: Linux Server
   - Download: `WindowsDefenderATPOnboardingPackage.zip`

2. **Extract onboarding package**:

   ```bash
   unzip WindowsDefenderATPOnboardingPackage.zip
   ```

3. **Run onboarding script**:

   ```bash
   sudo python3 MicrosoftDefenderATPOnboardingLinuxServer.py
   ```

4. **Verify onboarding**:

   ```bash
   mdatp health --field healthy
   ```

### Common Commands

```bash
# Check service health
mdatp health

# Get detailed health information
mdatp health --details

# Run quick scan
mdatp scan quick

# Run full scan
mdatp scan full --path /

# Check real-time protection status
mdatp config real-time-protection --value enabled

# View threat history
mdatp threat list

# Update definitions
mdatp definitions update

# Get version information
mdatp version
```

### Configuration

Edit `/etc/opt/microsoft/mdatp/managed/mdatp_managed.json` for managed configuration:

```json
{
  "antivirusEngine": {
    "enforcementLevel": "real_time",
    "scanAfterDefinitionUpdate": true,
    "scanArchives": true,
    "maximumOnDemandScanThreads": 2
  },
  "cloudService": {
    "enabled": true,
    "automaticSampleSubmission": true
  }
}
```

## Architecture

### FHSUserEnv Approach

This package uses Nix's `buildFHSUserEnv` to create a complete Linux Standard Base environment. This approach:

**Advantages:**

- ✅ Maximum compatibility with Microsoft's binary
- ✅ Minimal patching required
- ✅ Works with hardcoded paths (`/opt/`, `/etc/opt/`)
- ✅ Proven pattern for proprietary software

**Trade-offs:**

- ⚠️ Heavier resource usage (full FHS environment)
- ⚠️ Less integrated with NixOS ecosystem
- ⚠️ Isolated environment

### File Locations

| Component       | Location in FHS Environment            |
| --------------- | -------------------------------------- |
| Main daemon     | `/opt/microsoft/mdatp/sbin/wdavdaemon` |
| Client tool     | `/usr/bin/mdatp` (symlink)             |
| Configuration   | `/etc/opt/microsoft/mdatp/`            |
| Logs            | `/var/log/microsoft/mdatp/`            |
| Systemd service | `/lib/systemd/system/mdatp.service`    |

## Troubleshooting

### Service Won't Start

```bash
# Check systemd service status
systemctl status mdatp

# View detailed logs
journalctl -u mdatp -f

# Check health status
mdatp health
```

### Health Check Failures

```bash
# Common issues:
# 1. Onboarding not completed
sudo python3 /path/to/MicrosoftDefenderATPOnboardingLinuxServer.py

# 2. Network connectivity
curl -v https://events.data.microsoft.com

# 3. Service not running
systemctl restart mdatp
```

### Performance Issues

```bash
# Check CPU usage
mdatp health --field real_time_protection_cpu_usage

# Adjust scanning threads
mdatp config maximum-on-demand-scan-threads --value 1

# Check memory usage
ps aux | grep wdavdaemon
```

### Onboarding Errors

```bash
# Check organization ID
mdatp health --field org_id

# Re-run onboarding
sudo python3 /path/to/MicrosoftDefenderATPOnboardingLinuxServer.py

# Verify connectivity
curl -v https://winatp-gw-eus.microsoft.com
```

## Known Limitations

### NixOS-Specific Issues

1. **Non-FHS Layout**: NixOS uses `/nix/store/` instead of standard paths
   - **Mitigated by**: FHSUserEnv creating full LSB environment

2. **Binary-Only Distribution**: Cannot build from source
   - **Limitation**: Must accept Microsoft's compiled binaries
   - **Mitigation**: SHA256 hash verification for reproducibility

3. **Custom Paths Unsupported**: Microsoft requires default `/opt/` location
   - **Workaround**: FHS environment simulates expected structure

4. **Update Complexity**: Each version requires manual package update
   - **Process**: Download new .deb, calculate hash, update version

### General Limitations

1. **No PAC/WPAD Proxy Support**: Only static or transparent proxies
2. **No SSL Inspection**: Cannot inspect HTTPS traffic
3. **fanotify Conflicts**: Cannot run with other fanotify-based security
4. **noexec Mounts**: Cannot run from filesystems mounted with `noexec`

## Security Considerations

### Accepted Risks

- **Proprietary Binary**: Cannot audit source code
- **Elevated Privileges**: Requires root access for operation
- **Network Communication**: Sends data to Microsoft endpoints
- **System Access**: Requires access to all files and processes

### Mitigations

- **Hash Verification**: SHA256 verification for package integrity
- **Systemd Hardening**: DynamicUser, ProtectSystem when possible
- **Network Monitoring**: Monitor traffic to Microsoft endpoints
- **Audit Logging**: Enable comprehensive audit logs

## Development

### Building Package

```bash
# Test package build
nix-build -A mdatp

# Build and enter FHS environment
nix-shell default.nix

# Test within environment
./result/bin/mdatp-fhs-env
mdatp --help
```

### Updating Version

1. Download new .deb package
2. Calculate SHA256 hash: `sha256sum mdatp.deb`
3. Update `version` and `sha256` in `default.nix`
4. Test build: `nix-build -A mdatp`
5. Verify extraction: Check `/nix/store/*/opt/microsoft/mdatp`

### Testing

```bash
# Syntax check
just check-syntax

# Build test
just test-host HOST

# Full validation
just validate
```

## References

### Official Documentation

- [MDE Linux Prerequisites](https://learn.microsoft.com/en-us/defender-endpoint/mde-linux-prerequisites)
- [Manual Deployment Guide](https://learn.microsoft.com/en-us/defender-endpoint/linux-install-manually)
- [microsoft/mdatp-xplat GitHub](https://github.com/microsoft/mdatp-xplat)
- [What's New in MDE Linux](https://learn.microsoft.com/en-us/defender-endpoint/linux-whatsnew)

### NixOS Resources

- [buildFHSUserEnv Manual](https://nixos.org/manual/nixpkgs/stable/#sec-fhs-environments)
- [Packaging Binaries Guide](https://nixos.wiki/wiki/Packaging/Binaries)
- [NixOS Security Best Practices](https://nixos.org/manual/nixos/stable/#sec-hardening)

### Community

- [nixpkgs Issue #348654](https://github.com/NixOS/nixpkgs/issues/348654) - Previous packaging attempt
- [NixOS Discourse Discussion](https://discourse.nixos.org/t/microsoft-defender-for-endpoint/22572)

## License

This package wrapper is licensed under the MIT License.

**Note**: Microsoft Defender for Endpoint itself is proprietary software requiring commercial licensing from Microsoft. This package only provides the wrapper and integration for NixOS - it does not include or modify Microsoft's software.

## Maintainers

- [ ] Add maintainer information

## Changelog

### Version 101.25102.0003-insiderfast (2025-01-10)

- Initial NixOS package implementation
- FHSUserEnv wrapper for binary compatibility
- SHA256: `7723720b990d1e890eeba5e2a6beb4c92b04bde011359a96e2537ad85af5c9b2`

## Contributing

Contributions welcome! Please ensure:

- Follow NixOS packaging best practices
- Test on multiple NixOS versions
- Document any changes
- Update SHA256 hashes for new versions

## Support

For issues related to:

- **NixOS package**: Open issue in this repository
- **Microsoft Defender itself**: Contact Microsoft support
- **General questions**: NixOS Discourse or Matrix channels
