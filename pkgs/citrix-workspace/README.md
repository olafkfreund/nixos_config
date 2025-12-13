# Citrix Workspace Package Directory

This directory contains the Citrix Workspace package management system with USB support.

## Quick Setup (After Downloading Files)

### 1. Download Required Files

Visit: <https://www.citrix.com/downloads/workspace-app/linux/workspace-app-for-linux-latest.html>

Download the **main package** for version **2508.10**:

- `linuxx64-2508.10.tar.gz` (Full package including USB support)

**Note**: USB support is included in the main tar.gz. Do NOT download the separate .deb USB package.

### 2. Place File Here

```bash
mv ~/Downloads/linuxx64-2508.10.tar.gz /home/olafkfreund/.config/nixos/pkgs/citrix-workspace/
```

### 3. Verify Files

```bash
cd /home/olafkfreund/.config/nixos
./pkgs/citrix-workspace/fetch-citrix.sh
```

This will show you the computed hashes.

### 4. Update Configuration (AUTOMATED)

```bash
./pkgs/citrix-workspace/update-hashes.sh
```

This automatically updates both configuration files with the correct hashes!

### 5. Enable and Deploy

**Enable on P620:**

```bash
nano hosts/p620/configuration.nix
# Change: enable = false; to enable = true;
```

**Enable on Razer:**

```bash
nano hosts/razer/configuration.nix
# Change: enable = false; to enable = true;
```

**Deploy:**

```bash
just quick-deploy p620
just quick-deploy razer
```

## Files in This Directory

- `fetch-citrix.sh` - Download helper and hash calculator
- `update-hashes.sh` - Automatic hash updater for configuration files
- `default.nix` - Package definition
- `.gitignore` - Excludes binary tarballs from git
- `linuxx64-2508.10.tar.gz` - Main package (you download - includes USB support)
- `README.md` - This file

## What You Get

✅ **Full Citrix Workspace** (version 2508.10)
✅ **USB Device Redirection** (included in main package)
✅ **Automatic Integration** (seamless NixOS integration)
✅ **Easy Updates** (automated hash management)
✅ **All Dependencies** (gtk, multimedia, audio codecs)

## Troubleshooting

**Q: What if version 2508.10 isn't available?**

A: Download the latest version and update these files:

- `fetch-citrix.sh` - Change `VERSION="2508.10"`
- `default.nix` - Change `version = "2508.10";`
- `../../overlays/citrix-workspace.nix` - Change `version = "2508.10";`

**Q: Do I need the separate USB .deb package?**

A: **No!** USB support is already included in the main tar.gz package since version 2508.10.
Do NOT download the separate .deb USB package.

**Q: Can I use the system without Citrix?**

A: Yes! Citrix is disabled by default. Only enable on hosts where you need it.

## More Information

See: `/home/olafkfreund/.config/nixos/docs/CITRIX-WORKSPACE-SETUP.md`
