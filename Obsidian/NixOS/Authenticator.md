# GNOME Authenticator - TOTP/2FA Documentation

## Overview

**GNOME Authenticator** is a native two-factor authentication (2FA) code generator for GNOME
desktop environments. It provides a secure, offline solution for managing Time-based One-Time
Passwords (TOTP) and HOTP codes for your online accounts.

### Key Features

- 🔒 **Secure Local Storage**: All codes encrypted and stored locally using GNOME Keyring
- 📸 **QR Code Scanner**: Easy setup by scanning QR codes from services
- 🎨 **Beautiful Native UI**: Follows GNOME Human Interface Guidelines
- 🗄️ **Service Database**: Pre-configured for 560+ popular services with logos
- 🔐 **Password Protection**: Lock application with password for added security
- 🌐 **Offline Operation**: No internet required, completely private
- 🎭 **Dark Mode**: Automatic theme switching with system preferences

### Why Use Authenticator?

- **Privacy**: All data stays on your device, no cloud sync
- **Integration**: Native GNOME app with perfect desktop integration
- **Security**: Encrypted storage using GNOME Keyring
- **Reliability**: No dependency on mobile devices or SMS

## Installation

Authenticator is automatically installed on hosts with GNOME desktop enabled via the `desktop.gnome.apps.enable` option.

### Enabled Hosts

- **p620**: AMD workstation with GNOME
- **razer**: Intel/NVIDIA laptop with GNOME

### Configuration Files

- **Module**: `home/desktop/gnome/authenticator.nix`
- **Import**: `home/desktop/gnome/default.nix` (line 66)
- **Package**: `pkgs.authenticator` (version 4.6.2)

## Getting Started

### Launching the Application

1. **From Application Menu**: Search for "Authenticator" in GNOME Shell
2. **From Terminal**: Run `authenticator`
3. **Desktop File**: `/run/current-system/sw/share/applications/com.belmoussaoui.Authenticator.desktop`

### First-Time Setup

On first launch, you'll be prompted to:

1. **Create Master Password** (optional but recommended)
   - This encrypts your database
   - Required to unlock the app
   - Cannot be recovered if lost!

2. **Initial Configuration**
   - Choose dark/light theme (or follow system)
   - Configure backup reminders

## Adding Accounts

### Method 1: QR Code Scanning (Recommended)

1. Click **"+" (Add)** button in top bar
2. Select **"Scan QR Code"**
3. Point your webcam at the QR code displayed by the service
4. Account automatically added with:
   - Service name and logo
   - Account identifier (email/username)
   - Token settings (algorithm, period, digits)

### Method 2: Manual Entry

If QR code scanning isn't available:

1. Click **"+" (Add)** button
2. Select **"Enter Details Manually"**
3. Fill in the fields:
   - **Name**: Service name (e.g., "GitHub")
   - **Account**: Your username/email
   - **Secret Key**: The alphanumeric string provided by the service
   - **Algorithm**: Usually SHA-1 (default)
   - **Period**: Usually 30 seconds (default)
   - **Digits**: Usually 6 (default)

4. Click **"Add"** to save

### Method 3: Import from File

For migrating from other authenticator apps:

1. Export from other app (if supported)
2. **Menu** → **Import**
3. Select file format (varies by source)

## Using Authentication Codes

### Viewing Codes

- Codes refresh every 30 seconds (default)
- Progress indicator shows time remaining
- Codes are 6 digits (standard for most services)

### Copying Codes

1. **Single Click**: Select account
2. **Copy Button**: Click copy icon or press `Ctrl+C`
3. **Paste**: Code copied to clipboard, paste into login form

### Quick Actions

- **Search**: Press `/` to search accounts
- **Copy**: Click account + `Ctrl+C`
- **Edit**: Right-click → Edit
- **Delete**: Right-click → Remove

## Security Best Practices

### Password Protection

**Highly Recommended**: Enable master password protection

1. **Settings** → **Security**
2. **Set Master Password**
3. Choose strong, memorable password
4. **Never forget this password** - it cannot be recovered!

### Backup Strategy

**Critical**: Create regular backups of your accounts

#### Option 1: Manual Export

1. **Menu** → **Export**
2. Choose secure location (encrypted drive recommended)
3. **File format**: Encrypted JSON
4. Store backup securely (password manager, encrypted storage)

#### Option 2: Secret Key Backup

When adding accounts, save the secret key separately:

- Store in password manager (1Password, Bitwarden, etc.)
- Write down and store in secure physical location
- Allows manual re-creation if database lost

### Security Warnings

⚠️ **Do Not**:

- Share QR codes or secret keys
- Store backups unencrypted
- Use same password as other services
- Sync database to cloud services
- Screenshot codes or QR codes

✅ **Do**:

- Use strong master password
- Create regular encrypted backups
- Store backups separately from device
- Review account list periodically
- Remove accounts for deleted services

## Configuration

### Application Settings

Settings managed via dconf (automatically configured):

```nix
"com/belmoussaoui/Authenticator" = {
  window-width = 800;
  window-height = 600;
  is-maximized = false;
  backup-reminder-count = 10;
  prefer-dark-theme = true;  # Follows system theme
};
```

### Customization Options

Available through application settings:

- **Theme**: Light/Dark/Auto
- **Backup Reminders**: Frequency of backup prompts
- **Search**: Case sensitivity, fuzzy matching
- **Sorting**: Alphabetical, recently used, custom

## Common Use Cases

### Setting Up GitHub 2FA

1. GitHub → **Settings** → **Security** → **Two-factor authentication**
2. **Enable two-factor authentication**
3. Choose **"Set up using an app"**
4. **Scan QR code** with Authenticator
5. **Enter 6-digit code** to verify
6. **Save recovery codes** in secure location

### Setting Up Google Account 2FA

1. Google Account → **Security** → **2-Step Verification**
2. **Get Started** → **Authenticator app**
3. Choose **Android** or **iPhone** (works for Linux too)
4. **Scan QR code** with Authenticator
5. **Enter code** to verify

### Corporate VPN/SSO

Many enterprise systems use TOTP:

1. Contact IT for setup instructions
2. Usually provides QR code or secret key
3. Add to Authenticator
4. Use code for VPN/SSO login

## Troubleshooting

### Codes Not Working

**Issue**: Service rejects authentication code

**Solutions**:

1. **Check Time Sync**: Ensure system time is accurate

   ```bash
   timedatectl status
   # If wrong: sudo timedatectl set-ntp true
   ```

2. **Verify Settings**:
   - Algorithm: Usually SHA-1
   - Period: Usually 30 seconds
   - Digits: Usually 6

3. **Re-add Account**: Delete and set up again with new QR code

### QR Code Scanner Not Working

**Issue**: Camera not detected or QR code not recognized

**Solutions**:

1. **Check Camera Permissions**:

   ```bash
   ls /dev/video*
   # Should show camera devices
   ```

2. **Grant Permissions**: Settings → Privacy → Camera → Allow Authenticator

3. **Manual Entry**: Use secret key instead of QR code

### Application Won't Launch

**Issue**: Authenticator fails to start

**Solutions**:

1. **Check Installation**:

   ```bash
   which authenticator
   # Should output: /run/current-system/sw/bin/authenticator
   ```

2. **View Logs**:

   ```bash
   journalctl --user -f | grep -i authenticator
   ```

3. **Rebuild System**:

   ```bash
   just quick-deploy razer  # or p620
   ```

### Database Corruption

**Issue**: Cannot access saved accounts

**Solutions**:

1. **Restore from Backup**: Import previously exported backup
2. **Rebuild Database**: Delete `~/.local/share/Authenticator/` (⚠️ loses all accounts!)
3. **Manual Re-entry**: Use saved secret keys to recreate accounts

## Migration

### From Mobile Authenticator Apps

#### From Google Authenticator (Android/iOS)

1. **Export**: Use Google Authenticator export feature
2. **Transfer**: Note down secret keys or use transfer codes
3. **Import**: Manually add each account to GNOME Authenticator

#### From Authy

1. **Note**: Authy doesn't allow export easily
2. **Disable Authy Protection** temporarily on each account
3. **Get QR Codes**: Re-generate QR codes from each service
4. **Scan**: Add to GNOME Authenticator

#### From andOTP (Android)

1. **Export**: Settings → Backup → Export (encrypted JSON)
2. **Transfer**: Copy file to Linux machine
3. **Import**: GNOME Authenticator → Import → Select file

### To Mobile Device (For Travel)

1. **Export from Authenticator**
2. **Re-scan QR Codes**: Most services allow multiple devices
3. **Alternative**: Use secret keys to set up on mobile

## Advanced Features

### Command Line Interface

Authenticator supports command-line interaction:

```bash
# Generate code for specific account (if unlocked)
authenticator --generate "GitHub:username"

# List all accounts
authenticator --list

# Export database
authenticator --export /path/to/backup.json
```

### URI Handler

Authenticator registers as handler for `otpauth://` URIs:

```bash
# Automatically adds account
xdg-open "otpauth://totp/GitHub:username?secret=SECRETKEY&issuer=GitHub"
```

### Scripting Integration

For automation (use carefully, security implications):

```python
import gi
gi.require_version('Authenticator', '1.0')
from gi.repository import Authenticator

# Access codes programmatically (requires unlocked database)
```

## File Locations

### Configuration

- **Dconf Settings**: `~/.config/dconf/user` (binary)
- **App Data**: `~/.local/share/Authenticator/`
- **Database**: `~/.local/share/Authenticator/database.json` (encrypted)

### Backups

- **Default Export Location**: `~/Documents/`
- **Recommended Backup Location**: Encrypted external drive or password manager

## Security Model

### Encryption

- **Storage**: AES-256 encryption for database
- **Key Derivation**: PBKDF2 with user password
- **Keyring Integration**: GNOME Keyring stores encryption keys
- **No Network**: All operations offline, no telemetry

### Threat Model

**Protects Against**:

- Unauthorized local access (with password)
- Database theft (encrypted at rest)
- Service-specific token theft (unique per service)

**Does Not Protect Against**:

- Root access compromise (like all local apps)
- Physical access without full disk encryption
- Master password compromise
- QR code/secret key exposure before entry

## Resources

### Official Documentation

- **Homepage**: <https://gitlab.gnome.org/World/Authenticator>
- **GNOME Apps**: <https://apps.gnome.org/Authenticator/>
- **GitLab Issues**: <https://gitlab.gnome.org/World/Authenticator/issues>

### Related Tools

- **oathtool**: Command-line TOTP generation

  ```bash
  oathtool --totp SECRETKEY
  ```

- **GNOME Keyring**: Manages encryption keys

  ```bash
  seahorse  # GUI for keyring management
  ```

### Further Reading

- [RFC 6238 - TOTP Algorithm](https://tools.ietf.org/html/rfc6238)
- [RFC 4226 - HOTP Algorithm](https://tools.ietf.org/html/rfc4226)
- [GNOME HIG](https://developer.gnome.org/hig/)

## Maintenance

### Regular Tasks

- **Weekly**: Review account list for unused services
- **Monthly**: Create encrypted backup
- **Quarterly**: Verify backup restoration process
- **Annually**: Update master password

### Updating

Authenticator updates automatically with system:

```bash
# Update all packages
just update

# Deploy to specific host
just quick-deploy razer  # or p620
```

### Uninstalling

If needed to remove (not recommended):

1. **Export all accounts** first!
2. Disable GNOME apps: `desktop.gnome.apps.enable = false;`
3. Or remove from apps.nix package list

## Support

### Getting Help

1. **Check this documentation** first
2. **View logs**: `journalctl --user -f | grep -i authenticator`
3. **Test minimal config**: Create test account
4. **Community**: GNOME Discourse, Matrix chat
5. **Issues**: Report bugs to GitLab

### Reporting Issues

When reporting problems, include:

- NixOS version: `nixos-version`
- Authenticator version: `authenticator --version`
- Host: p620 or razer
- Steps to reproduce
- Error messages (if any)

## Conclusion

GNOME Authenticator provides enterprise-grade 2FA security with the privacy and control of local
storage. By following the best practices in this guide, you'll maintain secure access to all your
accounts while keeping complete control of your authentication codes.

**Remember**:

- 🔐 Use a strong master password
- 💾 Create regular backups
- 🔒 Store backups securely
- 🔍 Review accounts periodically

Stay secure! 🛡️

---

**Last Updated**: January 10, 2025
**Module Version**: 1.0.0
**Authenticator Version**: 4.6.2
