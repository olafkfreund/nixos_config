# 🔐 NixOS Secure Boot Setup Guide for Razer Blade

## Overview

This guide covers setting up Secure Boot on your Razer Blade using Lanzaboote, which is the recommended solution for NixOS Secure Boot support.

## What's Already Configured

✅ Added `lanzaboote` to flake inputs
✅ Added the lanzaboote module to all host configurations
✅ Created `hosts/razer/nixos/secure-boot.nix` configuration
✅ Added commented import to Razer configuration (ready to enable)
✅ Verified configuration builds successfully

## Step-by-Step Activation Process

### ⚠️ IMPORTANT: Backup First

Before proceeding, ensure you have:

- A working NixOS live USB or recovery method
- Your important data backed up
- Physical access to your laptop

---

### 1. Prepare Your BIOS/UEFI

**Boot into BIOS/UEFI settings:**

```bash
# Reboot and press F2 or Delete during boot
sudo systemctl reboot
```

**In BIOS settings:**

1. **Disable Secure Boot** temporarily
2. **Enable** "Setup Mode" or "Custom Secure Boot"
3. **Clear** existing Secure Boot keys (if any)
4. **Save and reboot** to NixOS

---

### 2. Generate and Install Secure Boot Keys

**Update your flake and activate Secure Boot config:**

```bash
# Update flake lock
cd /home/olafkfreund/.config/nixos
nix flake update lanzaboote

# Uncomment the secure-boot import in razer config
sudo nano hosts/razer/configuration.nix
# Change: # ./nixos/secure-boot.nix
# To:     ./nixos/secure-boot.nix

# Build and switch (this will fail the first time - that's expected)
sudo nixos-rebuild switch --flake .#razer
```

**Install Secure Boot keys:**

```bash
# Create the PKI bundle directory
sudo mkdir -p /etc/secureboot

# Generate Secure Boot keys
sudo sbctl create-keys

# Check current Secure Boot status
sudo sbctl status

# Enroll keys (this puts UEFI in "User Mode")
sudo sbctl enroll-keys -m

# Verify the keys are enrolled
sudo sbctl status
```

---

### 3. Sign Your Boot Components

**Sign the current system:**

```bash
# Check what needs to be signed
sudo sbctl verify

# Sign all required components (kernel, initrd, etc.)
sudo sbctl sign-all

# Verify everything is signed
sudo sbctl verify
```

---

### 4. Enable Secure Boot in BIOS

**Reboot to BIOS:**

```bash
sudo systemctl reboot
```

**In BIOS settings:**

1. **Enable Secure Boot**
2. **Set Secure Boot mode to "Custom"** (not "Standard")
3. **Save and exit**

---

### 5. Test and Verify

**After reboot, verify Secure Boot is working:**

```bash
# Check if Secure Boot is enabled
bootctl status

# Should show "Secure Boot: enabled"

# Check lanzaboote status
sudo sbctl status

# Verify all components are properly signed
sudo sbctl verify
```

---

### 6. Automatic Signing for Future Updates

Your configuration is already set up to automatically sign new kernels and updates. Every time you run `nixos-rebuild`, lanzaboote will:

- Automatically sign new kernels
- Update the boot loader
- Maintain Secure Boot compatibility

---

## 🔧 Configuration Details

**Your secure-boot.nix includes:**

- **Lanzaboote enabled** with PKI bundle in `/etc/secureboot`
- **systemd-boot disabled** (conflicts with lanzaboote)
- **sbctl package** for key management
- **EFI variables** still enabled for key management

**Key files and directories:**

- `/etc/secureboot/` - Your Secure Boot keys
- `/boot/EFI/nixos/` - Signed boot components
- Kernel and initrd automatically signed on each rebuild

---

## 🚨 Troubleshooting

### If boot fails after enabling Secure Boot

1. **Boot from NixOS live USB**
2. **Disable Secure Boot in BIOS** temporarily
3. **Boot into your system**
4. **Re-run signing process:**

   ```bash
   sudo sbctl sign-all
   sudo sbctl verify
   ```

5. **Re-enable Secure Boot**

### If keys get corrupted

```bash
# Recreate keys
sudo rm -rf /etc/secureboot
sudo sbctl create-keys
sudo sbctl enroll-keys -m
sudo sbctl sign-all
```

### Common Issues

**"Verification failed" errors:**

- Ensure you're in Setup Mode before enrolling keys
- Clear all existing keys in BIOS first
- Verify `/etc/secureboot` directory exists and has correct permissions

**Boot loop after enabling Secure Boot:**

- Boot from recovery USB
- Disable Secure Boot temporarily
- Check `sudo sbctl verify` output
- Re-sign any unsigned components

**Lanzaboote service fails:**

- Check logs: `journalctl -u lanzaboote`
- Verify PKI bundle path: `ls -la /etc/secureboot`
- Ensure boot.lanzaboote.enable = true in configuration

---

## ✅ Verification Commands

**Check everything is working:**

```bash
# Secure Boot status
bootctl status | grep "Secure Boot"

# Lanzaboote status
sudo sbctl status

# Verify signatures
sudo sbctl verify

# Check boot entries
bootctl list

# View detailed boot information
bootctl status
```

**Expected output when working correctly:**

```
# bootctl status should show:
Secure Boot: enabled (user)
Current Boot Loader: systemd-boot (not reported by efibootmgr)

# sbctl status should show:
Installed: ✓ sbctl is installed
Owner GUID: [your-guid]
Setup Mode: ✓ Disabled
Secure Boot: ✓ Enabled
Vendor Keys: none
```

---

## 📚 Additional Resources

- [Lanzaboote Documentation](https://github.com/nix-community/lanzaboote)
- [NixOS Wiki - Secure Boot](https://nixos.wiki/wiki/Secure_Boot)
- [UEFI Secure Boot Specification](https://uefi.org/specifications)

---

## 🔄 To Enable Secure Boot

**Ready to activate? Follow these steps:**

1. **Uncomment the import** in `hosts/razer/configuration.nix`:

   ```nix
   # Change this line:
   # ./nixos/secure-boot.nix

   # To this:
   ./nixos/secure-boot.nix
   ```

2. **Follow the activation steps** above starting from Step 1

3. **Test thoroughly** before considering the setup complete

**Note:** Once enabled, you cannot easily revert without losing the ability to boot. Ensure you have recovery options ready!
