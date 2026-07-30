# NixOS Live USB Management

Build, flash, and manage hardware-specific live USB installer images.

**Replaces Justfile recipes**: `build-all-live`, `show-devices`, `clean-live`, `live-help`, and flash operations

## Quick Usage

**Build live USB for host**:

```
/nix-live
Build p620
```

**Show available USB devices**:

```
/nix-live
Show devices
```

**Flash ISO to USB**:

```
/nix-live
Flash p620 to /dev/sdX
```

**Clean build artifacts**:

```
/nix-live
Clean
```

## Features

### Live USB Operations

**Build** (~10 minutes):

- ✅ Creates host-specific live USB ISO
- ✅ Includes hardware configuration
- ✅ Automated installation wizard
- ✅ SSH access enabled (root/nixos)
- ✅ Full tool suite included

**Show Devices** (instant):

- ✅ Lists all storage devices
- ✅ Shows device sizes and types
- ✅ Identifies USB devices
- ✅ Shows mount status
- ✅ Safe device selection

**Flash** (~5 minutes):

- ✅ Flashes ISO to USB device
- ✅ Verifies write success
- ✅ Syncs data to disk
- ✅ Safe unmounting
- ✅ Progress indication

**Clean** (~2 seconds):

- ✅ Removes build artifacts
- ✅ Cleans ISO files
- ✅ Frees disk space
- ✅ Keeps source files

### Build All Hosts

```
/nix-live
Build all hosts
```

- Builds ISOs for all 3 hosts
- Parallel building supported
- ~30 minutes total (sequential)
- ~10 minutes (if parallel)

## Live USB Workflow

### Creating Installation Media

**Step 1: Build Live ISO**

```bash
/nix-live
Build p620

# Result: result/iso/nixos-p620-live.iso
```

**Step 2: Identify USB Device**

```bash
/nix-live
Show devices

# /dev/sdc - 64GB USB Drive (mounted)
```

**Step 3: Flash to USB**

```bash
/nix-live
Flash p620 to /dev/sdb

# USB is ready!
```

### Using Live USB

**Boot from USB**:

1. Insert USB into target computer
2. Boot from USB (F12/F2/DEL in BIOS)
3. Live system starts automatically

**Install NixOS**:

```bash
# On live system, run installer
sudo install-p620

# Follow guided installation wizard
```

**SSH Installation** (Remote):

```bash
# On live system
ip addr  # Get IP address

# From remote computer
ssh root@<live-system-ip>

# Run installer remotely
sudo install-p620
```

## Output Format

### Show Devices Output

```
💾 Available Storage Devices

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Device Information
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/dev/sda (Internal SSD)
  Size:       1 TB
  Type:       SSD
  Model:      Samsung 990 PRO
  Mounted:    /
  Status:     🔒 System Disk (DO NOT USE)

/dev/sdb (USB Drive)
  Size:       32 GB
  Type:       USB Mass Storage
  Model:      SanDisk Ultra
  Mounted:    No
  Status:     ✅ Safe to use

/dev/sdc (USB Drive)
  Size:       64 GB
  Type:       USB Mass Storage
  Model:      Kingston DataTraveler
  Mounted:    /media/usb
  Status:     ⚠️  Currently mounted (unmount first)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Recommendations
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✅ Safe to use: /dev/sdb (32 GB, unmounted)
⚠️  Need to unmount: /dev/sdc (currently mounted)
🔒 Never use: /dev/sda (system disk!)

To flash: /nix-live Flash p620 to /dev/sdb
```

## Implementation Details

### Build Command

```bash
# Build live ISO for specific host
nix build .#packages.x86_64-linux.live-iso-p620

# Copy to result/iso/ for easy access
```

### Show Devices Command

```bash
# List all block devices with details
lsblk -o NAME,SIZE,TYPE,MODEL,MOUNTPOINT

# Warn about system disks
```

### Flash Command

```bash

# Flash ISO to device
sudo dd if=result/iso/nixos-p620-live.iso \
        of=/dev/sdX \
        bs=4M \
        status=progress \
        oflag=sync

# Sync and unmount
sudo sync
sudo umount /dev/sdX*
```

### Clean Command

```bash
# Remove ISO files
rm -rf result/iso/*.iso

# Remove symlinks
rm -f result
```

## Live USB Features

### Included Tools

**System Analysis**:

- Hardware detection (lshw, dmidecode, lscpu)
- Network tools (NetworkManager, SSH, curl, wget)
- Disk management (parted, fdisk, filesystem utilities)

**Development**:

- Editors (neovim, nano)
- Git version control
- Python 3 with common libraries
- Debugging tools (gdb, strace)

**Installation**:

- Automated installation wizard
- Hardware configuration parser
- Disk partitioning helpers
- Network configuration

**Monitoring**:

- System monitoring (htop, iotop, nethogs)
- Process management
- Resource analysis

### SSH Access

**Default Credentials**:

- Username: `root`
- Password: `nixos`

**Enable SSH** (automatic):

```bash
# Connect from remote:
ssh root@<live-system-ip>
```

### Installation Wizard

**Features**:

- Hardware auto-detection
- Guided disk partitioning
- Network configuration
- User account setup
- Automated installation

**Usage**:

```bash
# On live system
sudo install-p620

# 4. Install system
```

## Safety Features

### Device Verification

**Before Flashing**:

- ✅ Confirms device is removable
- ✅ Warns if device is mounted
- ✅ Shows device size and model
- ✅ Requires explicit confirmation
- ✅ Prevents system disk selection

**Warnings**:

```
⚠️  WARNING: About to erase /dev/sdb!
   Device: SanDisk Ultra (32 GB)
   All data will be lost!

   Type 'yes' to confirm: _
```

### Write Verification

**After Flashing**:

- ✅ Verifies write success
- ✅ Syncs data to disk
- ✅ Safely unmounts device
- ✅ Confirms completion

## Best Practices

### DO ✅

- Build ISO before attempting flash
- Use `show-devices` to identify correct USB
- Verify device path (double-check!)
- Back up USB data before flashing
- Wait for sync to complete
- Test USB boot before deployment

### DON'T ❌

- Flash to system disk (use show-devices!)
- Skip device verification (dangerous!)
- Remove USB during flash (corruption!)
- Use USB for other purposes (dedicated installer)
- Flash without confirmation (data loss!)

## Troubleshooting

### Build Fails

```bash
# Check available disk space
df -h

# Clean old builds
/nix-live
Clean

# Retry build
/nix-live
Build p620
```

### Flash Fails

```bash
# Check if device is mounted
lsblk | grep sdX

# Unmount if needed
sudo umount /dev/sdX*

# Retry flash
/nix-live
Flash p620 to /dev/sdX
```

### USB Won't Boot

```bash
# Verify ISO integrity
sha256sum result/iso/nixos-p620-live.iso

# - Set USB as first boot device
```

### Can't Find Device

```bash
# Rescan devices
/nix-live
Show devices

# Check if USB is detected
lsusb

# Try different USB drive
```

## Integration with Other Commands

### After Building

```bash
# Build ISO
/nix-live
Build p620

# Test configuration
/nix-test p620

# If test passes, flash
/nix-live
Flash p620 to /dev/sdb
```

### Before Deployment

```bash
# Validate configuration
/nix-validate
Full validation

# Build live USB
/nix-live
Build p620

# Deploy via USB
```

## Related Commands

- `/nix-test` - Test configuration before building ISO
- `/nix-validate` - Validate configuration
- `/nix-deploy` - Deploy to existing systems
- `/nix-info` - Check system information

---

**Pro Tip**: Keep a live USB for each host type for emergency recovery:

```bash
# Build recovery USBs
/nix-live Build all hosts

# Store in safe place
```

Emergency recovery is just a boot away! 💿
