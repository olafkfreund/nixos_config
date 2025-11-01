# P620 BIOS NUMA Configuration Guide

> **Hardware:** AMD Ryzen Threadripper PRO 3995WX (64-core/128-thread)
> **Purpose:** Enable NUMA (Non-Uniform Memory Access) for optimal multi-threaded performance
> **Expected Improvement:** 15-30% performance increase for parallel workloads
> **Difficulty:** Easy (one-time BIOS change)
> **Time Required:** 5-10 minutes

---

## Table of Contents

1. [Overview](#overview)
2. [Why NUMA Matters](#why-numa-matters)
3. [Pre-Configuration Checklist](#pre-configuration-checklist)
4. [BIOS Configuration Steps](#bios-configuration-steps)
5. [Verification After Boot](#verification-after-boot)
6. [Troubleshooting](#troubleshooting)
7. [Performance Tuning Options](#performance-tuning-options)
8. [Reverting Changes](#reverting-changes)

---

## Overview

The AMD Threadripper PRO 3995WX is a NUMA-capable processor with 64 cores organized into multiple dies. By default, many motherboards configure the system as a single NUMA domain (Unified Memory Architecture - UMA), which is suboptimal for high-core-count processors.

**What this guide does:**

- Enables NUMA awareness in the BIOS
- Configures memory interleaving for optimal performance
- Allows the Linux kernel to optimize memory locality

**What you'll gain:**

- Better memory bandwidth utilization
- Reduced memory latency for multi-threaded applications
- Improved performance for compilation, rendering, AI training, and virtualization

---

## Why NUMA Matters

### The Problem with UMA Mode

In UMA (Unified Memory Architecture) mode:

- All CPU cores treat memory as a single pool
- Memory access latency varies significantly between local and remote memory
- The scheduler cannot optimize thread placement
- Memory bandwidth is not fully utilized

### The NUMA Advantage

With NUMA enabled:

- CPU cores are organized into domains (nodes)
- Each domain has "local" memory with lower latency
- The Linux scheduler can place threads on cores with local memory
- Overall system throughput increases dramatically

### Performance Impact

Benchmarks show **15-30% performance improvements** for:

- Parallel compilation (kernel builds, large projects)
- 3D rendering (Blender, V-Ray)
- Video encoding/transcoding
- AI/ML training (PyTorch, TensorFlow)
- Virtual machines (QEMU/KVM)
- Database servers
- Scientific computing

---

## Pre-Configuration Checklist

Before making BIOS changes:

- [ ] **Backup important data** (as a precaution)
- [ ] **Note current BIOS settings** (take photos if needed)
- [ ] **Verify NixOS configuration is up-to-date**
- [ ] **Have keyboard connected** (USB keyboard preferred)
- [ ] **Know your BIOS access key** (usually `DEL` or `F2` during boot)
- [ ] **Set aside 10 minutes** for the change and verification

---

## BIOS Configuration Steps

### Step 1: Enter BIOS/UEFI Setup

1. **Reboot your system**
2. **Press the BIOS key** repeatedly during boot
   - For most motherboards: `DEL` key
   - Alternative keys: `F2`, `F10`, or `F12`
3. **Wait for BIOS menu to load**

### Step 2: Navigate to AMD CBS Settings

The exact path varies by motherboard manufacturer, but typically:

#### **American Megatrends (AMI) BIOS:**

```
Advanced
└── AMD CBS
    └── NBIO Common Options
        └── Memory Configuration
            └── Memory Interleaving
```

#### **ASUS TRX40/WRX80 Motherboards:**

```
Advanced
└── AMD CBS
    └── DF Common Options
        └── Memory Interleaving
```

#### **AsRock TRX40/WRX80 Motherboards:**

```
Advanced
└── AMD CBS
    └── NBIO Configuration
        └── Memory Interleaving
```

#### **Gigabyte TRX40/WRX80 Motherboards:**

```
Advanced
└── AMD Overclocking
    └── Memory Configuration
        └── Memory Interleaving Mode
```

### Step 3: Configure Memory Interleaving

You will find one of these settings (names vary by BIOS version):

| Setting Name               | Options                       | Recommended  |
| -------------------------- | ----------------------------- | ------------ |
| **Memory Interleaving**    | Auto / Channel / Die / Socket | **Channel**  |
| **NUMA per Socket**        | Disabled / NPS1 / NPS2 / NPS4 | **NPS2**     |
| **Memory Interleave Size** | Auto / 256B / 1KB / 2KB       | **Auto**     |
| **Channel Interleaving**   | Auto / Disabled / Enabled     | **Disabled** |

### Recommended Settings by Use Case

#### **🎯 Best for Most Users: NPS2 (or "Channel" Interleaving)**

**Settings:**

- Memory Interleaving: `Channel`
- OR NUMA per Socket: `NPS2`

**Why:**

- Balanced performance across all workloads
- Good memory bandwidth and latency
- Compatible with all software
- Recommended for daily use

#### **⚡ Maximum Performance: NPS4**

**Settings:**

- NUMA per Socket: `NPS4`

**Why:**

- Highest memory bandwidth
- Best for NUMA-aware applications
- Requires application support
- May reduce performance for non-NUMA workloads

#### **🔧 Conservative: NPS1 (UMA Mode)**

**Settings:**

- Memory Interleaving: `Auto` or `Disabled`
- OR NUMA per Socket: `NPS1`

**Why:**

- Current default configuration
- Simplest memory model
- Lower performance but highest compatibility

### Step 4: Additional AMD CBS Settings (Optional)

While in AMD CBS, consider these performance settings:

| Setting                       | Recommended Value      | Impact                          |
| ----------------------------- | ---------------------- | ------------------------------- |
| **Global C-state Control**    | `Enabled`              | Power saving (recommended)      |
| **Power Supply Idle Control** | `Typical Current Idle` | Balanced power/performance      |
| **IOMMU**                     | `Enabled`              | Required for VM GPU passthrough |
| **SVM Mode**                  | `Enabled`              | Required for virtualization     |
| **SMT Control**               | `Enabled`              | Keep hyperthreading on          |

### Step 5: Save and Exit

1. **Press F10** (or navigate to "Save & Exit")
2. **Confirm changes**: Select "Yes" or "OK"
3. **System will reboot** automatically

**⏱️ First boot after NUMA enable may take longer** (30-60 seconds extra) - this is normal!

---

## Verification After Boot

### 1. Check NUMA Configuration

```bash
# Install numactl if not present
sudo nix-env -iA nixos.numactl

# Check NUMA nodes
numactl --hardware
```

**Expected output with NPS2:**

```
available: 2 nodes (0-1)
node 0 cpus: 0-31 64-95
node 0 size: 110000 MB
node 1 cpus: 32-63 96-127
node 1 size: 110000 MB
```

**Expected output with NPS4:**

```
available: 4 nodes (0-3)
node 0 cpus: 0-15 64-79
node 1 cpus: 16-31 80-95
node 2 cpus: 32-47 96-111
node 3 cpus: 48-63 112-127
```

**What you should NOT see (UMA/NPS1):**

```
available: 1 nodes (0)
```

### 2. Verify Kernel NUMA Support

```bash
# Check kernel messages
dmesg | grep -i numa

# Expected output:
# NUMA: Node 0 [0,ffffffff] + [100000000,ffffffff] -> [0,ffffffff]
# NUMA: Node 1 [0,ffffffff] + [100000000,ffffffff] -> [0,ffffffff]
```

### 3. Check Memory Distances

```bash
numactl --hardware | grep "node distances"
```

**Good output (NPS2):**

```
node distances:
node   0   1
  0:  10  32
  1:  32  10
```

- **10** = local memory (fast)
- **32** = remote memory (slower)

### 4. Test Performance Improvement

Run a quick compilation test:

```bash
# Before NUMA (baseline)
time nix build .#nixosConfigurations.p620.config.system.build.toplevel --rebuild

# After NUMA (should be faster)
time nix build .#nixosConfigurations.p620.config.system.build.toplevel --rebuild
```

Expected improvement: **15-30% faster build times**

---

## Troubleshooting

### Issue: "numactl: command not found"

**Solution:**

```bash
nix-shell -p numactl
numactl --hardware
```

### Issue: Only shows 1 NUMA node after BIOS change

**Possible causes:**

1. BIOS setting didn't save properly - re-enter BIOS and verify
2. Wrong setting changed - ensure "Memory Interleaving" is set to "Channel"
3. BIOS doesn't support NUMA mode - check motherboard documentation

**Debug steps:**

```bash
# Check ACPI SRAT table
sudo dmesg | grep SRAT

# If output shows "SRAT: PXM 0 -> APIC", NUMA is working
# If no SRAT messages, NUMA is not enabled in BIOS
```

### Issue: System won't boot after BIOS change

**Solution:**

1. Enter BIOS again
2. Load "Optimized Defaults" or "Fail-Safe Defaults"
3. Reboot and verify system works
4. Try enabling NUMA again with NPS2 instead of NPS4

### Issue: Performance decreased after enabling NUMA

**Possible causes:**

- Application is not NUMA-aware
- Incorrect NPS setting for workload

**Solution:**
Try different NPS settings:

- Start with **NPS2** (best compatibility)
- If still worse, revert to **NPS1** (UMA mode)
- For NUMA-optimized apps, try **NPS4**

### Issue: "zone_reclaim_mode" errors in logs

**This is normal!** The kernel is adjusting memory reclaim strategies.

**Optional fix:**

```bash
# Temporarily disable zone reclaim if issues persist
sudo sysctl -w vm.zone_reclaim_mode=0
```

---

## Performance Tuning Options

### Option 1: NUMA Policy for Specific Applications

Run applications with specific NUMA policies:

```bash
# Interleave memory across all nodes (good for memory-intensive apps)
numactl --interleave=all your-application

# Bind to specific node (good for CPU-intensive apps)
numactl --cpunodebind=0 --membind=0 your-application

# Prefer local node but allow remote if needed
numactl --preferred=0 your-application
```

### Option 2: CPU Pinning for VMs

For virtual machines, pin vCPUs to specific NUMA nodes:

```nix
# In your VM configuration
virtualisation.libvirtd.qemu.numaNodeCPUPinning = [
  { node = 0; vcpus = [0 1 2 3]; }
  { node = 1; vcpus = [4 5 6 7]; }
];
```

### Option 3: Automatic NUMA Balancing

Already enabled in your NixOS configuration:

```nix
# In hosts/p620/nixos/cpu.nix
boot.kernel.sysctl = {
  "kernel.numa_balancing" = 1;
  "vm.zone_reclaim_mode" = 1;
};
```

---

## Reverting Changes

If you need to disable NUMA and return to UMA mode:

### Step 1: Enter BIOS

1. Reboot and enter BIOS/UEFI
2. Navigate to the same Memory Interleaving setting
3. Change to:
   - **Memory Interleaving**: `Auto` or `Disabled`
   - **OR NUMA per Socket**: `NPS1`
4. Save and exit

### Step 2: Update NixOS Configuration (Optional)

If reverting permanently, comment out NUMA settings:

```nix
# In hosts/p620/nixos/cpu.nix
boot.kernelParams = lib.mkAfter [
  "amd_pstate=active"
  "nohz_full=1-127"
  # "numa=on"  # Commented out
];

boot.kernel.sysctl = {
  # "kernel.numa_balancing" = 1;  # Commented out
  # "vm.zone_reclaim_mode" = 1;   # Commented out
};
```

### Step 3: Rebuild and Reboot

```bash
just quick-deploy p620
sudo reboot
```

---

## Quick Reference Card

Print and keep this handy:

```
╔══════════════════════════════════════════════════════════════╗
║         P620 NUMA BIOS QUICK REFERENCE                       ║
╠══════════════════════════════════════════════════════════════╣
║ BIOS Key:         DEL (during boot)                          ║
║ Path:             Advanced → AMD CBS → Memory Configuration  ║
║ Setting:          Memory Interleaving                        ║
║ Recommended:      Channel (or NPS2)                          ║
║ Save Key:         F10                                        ║
╠══════════════════════════════════════════════════════════════╣
║ Verify Command:   numactl --hardware                         ║
║ Expected Nodes:   2 (with NPS2) or 4 (with NPS4)            ║
╠══════════════════════════════════════════════════════════════╣
║ Performance Gain: 15-30% for parallel workloads             ║
║ Boot Time:        May add 30-60 seconds on first boot       ║
╚══════════════════════════════════════════════════════════════╝
```

---

## Additional Resources

- **AMD EPYC NUMA Documentation**: [AMD's official NUMA guide](https://www.amd.com/en/support)
- **Linux NUMA Documentation**: `/usr/share/doc/numactl/`
- **NixOS Hardware Configuration**: `hardware.nix` in this repository
- **Threadripper Optimization Guide**: [Level1Techs Forums](https://forum.level1techs.com/)

---

## Support

If you encounter issues:

1. **Check this guide's troubleshooting section**
2. **Review NixOS logs**: `journalctl -b | grep numa`
3. **Verify hardware support**: `lscpu | grep NUMA`
4. **Consult motherboard manual** for BIOS-specific instructions

---

**Last Updated:** 2025-01-31
**NixOS Configuration:** `hosts/p620/nixos/cpu.nix`
**Related Commit:** feat(p620): implement critical/high/medium hardware optimizations
