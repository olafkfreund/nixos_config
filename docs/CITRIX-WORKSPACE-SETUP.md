# Citrix Workspace Setup Guide

> **Critical Client Project Requirement**
> Last Updated: 2025-12-12
> Status: Implementation Ready

## 🎯 **Quick Start: Get Citrix Working NOW**

### **Option 1: Manual Tarball Installation** (REQUIRED - 15 minutes)

Citrix requires manual download due to EULA acceptance. Follow these steps:

#### **Step 1: Download Citrix Workspace Tarball**

```bash
# Open browser and navigate to:
# https://www.citrix.com/downloads/workspace-app/linux/workspace-app-for-linux-latest.html

# Download: linuxx64-25.05.0.44.tar.gz (or latest version)
# Save to: ~/Downloads/
```

#### **Step 2: Add Tarball to Nix Store**

```bash
cd ~/Downloads

# Add tarball to nix store with EULA acceptance
nix-prefetch-url file://$PWD/linuxx64-25.05.0.44.tar.gz

# This will output a SHA256 hash like:
# sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=
```

#### **Step 3: Update Module Configuration**

The module is already configured in:

- `/home/olafkfreund/.config/nixos/modules/services/citrix-workspace.nix`
- Enabled on p620 and razer hosts

#### **Step 4: Deploy**

```bash
# After adding tarball to store, deploy:
just quick-deploy p620
just quick-deploy razer
```

### **Option 2: HTML5/Browser Access** (IMMEDIATE - 5 minutes)

If you need access RIGHT NOW while waiting for tarball download:

```bash
# Simply open your web browser and navigate to:
# https://[your-client-citrix-url]

# Click "Use light version" or "Browser Access"
# No installation required!
```

**Limitations**:

- ⚠️ No USB passthrough
- ⚠️ Potential performance reduction

## 📋 **Current Status**

### ✅ **Completed**

1. Created `citrix-workspace.nix` module with security hardening
2. Module properly imports and enables on p620 and razer
3. Configuration uses `allowBroken` and `permittedInsecurePackages`
4. Firewall rules configured for Citrix ICA ports
5. Desktop integration enabled
6. Syntax validation passed

### ⏳ **Remaining**

1. Manual tarball download (EULA requirement)
2. Add tarball to nix store with `nix-prefetch-url`
3. Deploy and test connection

## 🔧 **Technical Details**

### **Module Configuration**

Located: `modules/services/citrix-workspace.nix`

```nix
services.citrix-workspace = {
  enable = true;
  acceptLicense = true; # EULA acceptance
};
```

### **What the Module Does**

1. **Allows Broken/Insecure Packages**:

   ```nix
   nixpkgs.config = {
     allowUnfree = true;
     allowBroken = true;
     permittedInsecurePackages = [
       "libsoup-2.74.3"
       "webkitgtk-2.42.4"
     ];
   };
   ```

2. **Firewall Configuration**:

   ```nix
   networking.firewall = {
     allowedTCPPorts = [
       1494  # Citrix ICA
       2598  # Citrix Session Reliability
     ];
     allowedUDPPorts = [
       1604  # Citrix ICA Browser
       16500 # Citrix Receiver Audio
     ];
   };
   ```

3. **System Integration**:
   - DBus enabled
   - UDisks2 enabled
   - Desktop integration
   - XDG MIME support

### **Enabled Hosts**

**P620** (Workstation):

```nix
# hosts/p620/configuration.nix:297-300
services.citrix-workspace = {
  enable = true;
  acceptLicense = true;
};
```

**Razer** (Laptop):

```nix
# hosts/razer/configuration.nix:184-187
services.citrix-workspace = {
  enable = true;
  acceptLicense = true;
};
```

## 🐛 **Known Issues & Solutions**

### **Issue 1: Package Marked as Broken**

**Symptom**: `meta.broken = true` in nixpkgs

**Solution**: Our module sets `allowBroken = true`

### **Issue 2: webkitgtk_4_0 Dependency**

**Symptom**: Missing `libwebkit2gtk-4.0.so.37`

**Solution**: Module permits insecure webkitgtk package

### **Issue 3: libsoup-2 Insecure**

**Symptom**: Package marked insecure

**Solution**: Added to `permittedInsecurePackages`

### **Issue 4: Manual Download Required**

**Symptom**:

```text
In order to use Citrix Workspace, you need to comply with the Citrix EULA
and download the 64-bit binaries
```

**Solution**: Manual download + `nix-prefetch-url` (see Step 1-2 above)

## 📦 **Package Versions**

**Current nixpkgs version**: `25.05.0.44`
**Download URL**: <https://www.citrix.com/downloads/workspace-app/linux/workspace-app-for-linux-latest.html>

If version 25.05.0.44 not available, try: <https://www.citrix.com/downloads/workspace-app/>

## 🚀 **Usage After Installation**

### **Launch Citrix Workspace**

**From Command Line**:

```bash
citrix-workspace
```

**From Desktop**:

- Application Menu → Internet → Citrix Workspace
- Or search for "Citrix" in app launcher

### **Connect to Client Environment**

1. Open Citrix Workspace
2. Enter client StoreFront/Gateway URL
3. Authenticate with client credentials
4. Select virtual desktop or application

### **Troubleshooting Connection**

```bash
# Check if service is running
systemctl status citrix-workspace

# Check firewall rules
sudo iptables -L | grep -i citrix

# Test network connectivity
ping [client-citrix-server]

# View Citrix logs
journalctl -u citrix-workspace -f
```

## 🔐 **Security Considerations**

1. **EULA Acceptance**: Required for Citrix download
2. **Insecure Packages**: Permitted for compatibility
3. **Firewall**: Specific ports opened for ICA protocol
4. **Network**: VPN recommended for client access
5. **Credentials**: Store securely, never in config files

## 📚 **References**

**Official Documentation**:

- [Citrix Workspace Downloads](https://www.citrix.com/downloads/workspace-app/linux/workspace-app-for-linux-latest.html)
- [NixOS Citrix Manual](https://ryantm.github.io/nixpkgs/builders/packages/citrix/)

**Community Resources**:

- [GitHub Issue #454151](https://github.com/nixos/nixpkgs/issues/454151)
- [NixOS Discourse - Citrix Installation](https://discourse.nixos.org/t/citrix-workspace-installation/9777)

**Internal Documentation**:

- [GitHub Issue #76](https://github.com/olafkfreund/nixos_config/issues/76)
- Module: `modules/services/citrix-workspace.nix`

## ✅ **Success Criteria**

- [ ] Tarball downloaded from Citrix
- [ ] Tarball added to nix store with `nix-prefetch-url`
- [ ] P620 deployed successfully
- [ ] Razer deployed successfully
- [ ] Connection to client environment tested
- [ ] Performance acceptable for client work
- [ ] Team members trained on usage

## 🆘 **Support**

**If Issues Persist**:

1. Check logs: `journalctl -u citrix-workspace -f`
2. Verify firewall: `sudo iptables -L`
3. Test HTML5 alternative
4. Contact client IT support
5. Update GitHub issue #76 with findings

---

**Next Steps**: Download tarball → `nix-prefetch-url` → Deploy → Test → Client work! 🚀
