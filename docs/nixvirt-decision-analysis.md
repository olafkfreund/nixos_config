# NixVirt Implementation Decision Analysis

> Issue: #8
> Date: 2025-12-05
> Status: Analysis Complete

## Executive Summary

NixVirt provides **declarative libvirt VM management** to complement your existing microvm.nix setup, enabling **Windows VM support** and **professional virtualization features**. This is a **complementary addition**, not a replacement.

## What is NixVirt?

### Core Concept

NixVirt is a NixOS/Home Manager module that enables **infrastructure-as-code** management of libvirt virtual machines. Instead of manually configuring VMs through virt-manager, you declare VMs in Nix configuration files.

**Key Principle**: "VMs as Code" - version-controlled, reproducible, declarative VM definitions

### Technical Foundation

- **Backend**: libvirt (industry-standard virtualization API)
- **Frontend**: Python tool called `virtdeclare` for idempotent operations
- **Integration**: NixOS module + Home Manager module
- **Templates**: Pre-built configurations for Linux, Windows 11, basic PCs

### What It Does

```nix
# Instead of clicking through virt-manager...
# You write declarative Nix code:

virtualisation.libvirt.connections."qemu:///system".domains = [{
  definition = NixVirt.lib.domain.writeXML (
    NixVirt.lib.domain.templates.windows11 {
      name = "windows-dev";
      uuid = "550e8400-e29b-41d4-a716-446655440000";
      memory = { count = 16; unit = "GiB"; };
      storage_vol = { pool = "default"; volume = "windows.qcow2"; };
      install_vol = "/path/to/windows11.iso";
    }
  );
  active = true;  # Auto-start on boot
}];
```

## What Needs to Be Done

### Phase 1: Core Setup (2 hours)

**1. Add NixVirt to flake.nix**

```nix
# In flake.nix inputs:
inputs.NixVirt = {
  url = "https://flakehub.com/f/AshleyYakeley/NixVirt/*.tar.gz";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

**⚠️ CRITICAL**: Must use **FlakeHub**, NOT GitHub master (master is frequently broken)

**2. Create NixVirt Module**

```nix
# modules/virtualization/nixvirt.nix
{ config, lib, pkgs, ... }:
with lib; let
  cfg = config.features.virtualization.nixvirt;
in {
  options.features.virtualization.nixvirt = {
    enable = mkEnableOption "NixVirt declarative VM management";

    connections = mkOption {
      type = types.attrs;
      default = {};
      description = "Libvirt connection configurations";
    };
  };

  config = mkIf cfg.enable {
    virtualisation.libvirt = {
      enable = true;
      swtpm.enable = true;  # TPM 2.0 for Windows 11
    };

    # Ensure user in libvirtd group
    users.users.${config.mainUser}.extraGroups = [ "libvirtd" ];
  };
}
```

**3. Enable on P620**

```nix
# hosts/p620/configuration.nix
features.virtualization.nixvirt = {
  enable = true;
  connections."qemu:///system" = {
    # VM definitions here
  };
};
```

**4. Test Build**

```bash
just test-host p620
```

### Phase 2: VM Creation (3 hours)

**1. Create Test Linux VM**

```nix
# Example: Debian testing VM
virtualisation.libvirt.connections."qemu:///system".domains = [{
  definition = NixVirt.lib.domain.writeXML (
    NixVirt.lib.domain.templates.linux {
      name = "debian-test";
      uuid = "550e8400-e29b-41d4-a716-446655440001";
      memory = { count = 8; unit = "GiB"; };
      storage_vol = {
        pool = "default";
        volume = "debian-test.qcow2";
        size = { count = 50; unit = "GiB"; };
      };
    }
  );
  active = false;  # Manual start
}];
```

**2. Create Windows 11 VM (if needed)**

```nix
virtualisation.libvirt.connections."qemu:///system".domains = [{
  definition = NixVirt.lib.domain.writeXML (
    NixVirt.lib.domain.templates.windows11 {
      name = "windows-dev";
      uuid = "550e8400-e29b-41d4-a716-446655440002";
      memory = { count = 16; unit = "GiB"; };
      vcpu = { count = 8; };

      # Secure Boot + TPM 2.0 (required for Windows 11)
      firmware = "/run/libvirt/nix-ovmf/OVMF_CODE.secboot.fd";
      nvram_path = "/var/lib/libvirt/qemu/nvram/windows-dev_VARS.fd";

      storage_vol = {
        pool = "default";
        volume = "windows-dev.qcow2";
        size = { count = 100; unit = "GiB"; };
      };

      install_vol = "/var/lib/libvirt/images/Win11_23H2_English_x64v2.iso";

      # Performance optimizations
      features = {
        hyperv = {
          relaxed = true;
          vapic = true;
          spinlocks = true;
        };
      };
    }
  );
  active = false;
}];
```

**3. Configure Networking**

```nix
# Declarative network bridge
virtualisation.libvirt.connections."qemu:///system".networks = [{
  definition = NixVirt.lib.network.writeXML {
    name = "vm-bridge";
    uuid = "550e8400-e29b-41d4-a716-446655440100";

    forward = { mode = "nat"; };
    bridge = { name = "virbr1"; };

    ip = {
      address = "192.168.100.1";
      netmask = "255.255.255.0";
      dhcp = {
        range = {
          start = "192.168.100.100";
          end = "192.168.100.200";
        };
      };
    };
  };
  active = true;
}];
```

**4. Configure Storage**

```nix
# Declarative storage pool
virtualisation.libvirt.connections."qemu:///system".pools = [{
  definition = NixVirt.lib.pool.writeXML {
    name = "vm-storage";
    uuid = "550e8400-e29b-41d4-a716-446655440200";
    type = "dir";

    target = { path = "/var/lib/libvirt/images"; };
  };
  active = true;
}];
```

### Phase 3: Integration (2 hours)

**1. Documentation**

- Document VM purposes in configuration comments
- Create VM usage guide in `docs/nixvirt-usage.md`
- Update CLAUDE.md with NixVirt information

**2. Testing**

```bash
# Build and deploy
just validate
just test-host p620
just p620

# Verify VMs
virsh list --all

# Start a VM
virsh start debian-test

# Check VM console
virt-viewer debian-test
```

**3. Cleanup**

- Remove any temporary test VMs
- Finalize configuration
- Update roadmap

## How It Works

### Architecture

```
┌─────────────────────────────────────────────┐
│         NixOS Configuration                  │
│                                              │
│  ┌────────────────────────────────────────┐ │
│  │ NixVirt Module                          │ │
│  │ - VM definitions in Nix                 │ │
│  │ - Network definitions                   │ │
│  │ - Storage pool definitions              │ │
│  └──────────────┬──────────────────────────┘ │
│                 │                             │
└─────────────────┼─────────────────────────────┘
                  │
                  ▼
         ┌────────────────┐
         │   virtdeclare  │  (Python tool)
         │ - Reads XML    │
         │ - Applies to   │
         │   libvirt      │
         └────────┬───────┘
                  │
                  ▼
         ┌────────────────┐
         │    libvirt     │  (Virtualization API)
         │ - QEMU/KVM     │
         │ - Networking   │
         │ - Storage      │
         └────────┬───────┘
                  │
                  ▼
         ┌────────────────┐
         │  Virtual VMs   │
         │ - Linux VMs    │
         │ - Windows VMs  │
         │ - Networks     │
         └────────────────┘
```

### Interaction with Existing Infrastructure

**Complements microvm.nix:**

```
┌──────────────────────────────────────────────┐
│ Your Infrastructure                           │
│                                               │
│ ┌────────────────┐    ┌─────────────────┐   │
│ │  microvm.nix   │    │    NixVirt      │   │
│ │                │    │                 │   │
│ │ - NixOS VMs    │    │ - Windows VMs   │   │
│ │ - Lightweight  │    │ - Linux VMs     │   │
│ │ - Fast boot    │    │ - Secure Boot   │   │
│ │ - Shared /nix  │    │ - TPM support   │   │
│ │                │    │ - Full features │   │
│ └────────────────┘    └─────────────────┘   │
│                                               │
│ Use microvm.nix for:    Use NixVirt for:     │
│ - Dev environments      - Windows testing    │
│ - Quick testing         - Professional VMs   │
│ - NixOS-only           - Mixed OS            │
└──────────────────────────────────────────────┘
```

**NOT a replacement** - both coexist for different purposes

## Impact Analysis

### ✅ **What This Solves**

#### Problem 1: No Windows VM Support

**Current situation:**

- Your infrastructure is 100% NixOS/Linux
- No way to test Windows-specific scenarios
- Can't develop cross-platform applications
- Limited enterprise compatibility testing

**With NixVirt:**

- Declarative Windows 11 VMs with Secure Boot + TPM
- Professional Windows development environment
- Cross-platform testing capabilities
- Enterprise compatibility validation

**Value**: **HIGH** if you need Windows testing, **NONE** if you don't

#### Problem 2: No Professional VM Features

**Current situation:**

- microvm.nix is lightweight but limited
- No Secure Boot support
- No TPM emulation
- No advanced VM features

**With NixVirt:**

- Full QEMU/KVM feature set
- Secure Boot support
- TPM 2.0 emulation (for BitLocker, etc.)
- Snapshots, cloning, advanced storage

**Value**: **MEDIUM** - nice to have for professional workloads

#### Problem 3: Manual VM Management

**Current situation:**

- If you need libvirt VMs, must configure via virt-manager
- No infrastructure-as-code for traditional VMs
- Can't version control VM definitions
- Inconsistent VM configurations

**With NixVirt:**

- Infrastructure-as-code for all VMs
- Version-controlled VM definitions
- Reproducible deployments
- GitOps-compatible workflows

**Value**: **HIGH** - aligns with your infrastructure philosophy

### ⚠️ **What This Doesn't Solve**

1. **Doesn't replace microvm.nix**
   - microvm.nix is still better for lightweight NixOS VMs
   - Don't migrate existing microvm.nix setups to NixVirt

2. **Doesn't provide GUI management**
   - Still need virt-manager for visual management
   - NixVirt is for declarative config, not GUI

3. **Doesn't simplify VM management**
   - Adds complexity compared to virt-manager clicks
   - Requires understanding Nix + libvirt concepts

4. **Doesn't improve performance**
   - Same QEMU/KVM backend as manual setup
   - No performance advantage over virt-manager VMs

## Is It Worth It?

### Decision Matrix

| Your Use Case                     | Recommendation | Rationale                                    |
| --------------------------------- | -------------- | -------------------------------------------- |
| **Need Windows VMs**              | ✅ **YES**     | This is the primary reason to implement      |
| **Want professional VM features** | ✅ **YES**     | Secure Boot, TPM, full QEMU features         |
| **Align with IaC philosophy**     | ✅ **YES**     | Infrastructure-as-code matches your approach |
| **Multi-host VM coordination**    | ✅ **YES**     | Single flake manages VMs across hosts        |
| **Just need NixOS VMs**           | ❌ **NO**      | microvm.nix is better                        |
| **Prefer GUI management**         | ❌ **NO**      | Just use virt-manager directly               |
| **Don't need VMs at all**         | ❌ **NO**      | Don't add unused complexity                  |

### For YOUR Infrastructure Specifically

**Context from your setup:**

- ✅ You already use microvm.nix (P510, P620)
- ✅ You value infrastructure-as-code (entire config is declarative)
- ✅ You have multi-host architecture
- ✅ P620 is a workstation suitable for VMs
- ⚠️ No apparent Windows development needs (currently)
- ⚠️ No mention of cross-platform testing requirements

**Assessment:**

```
VALUE SCORE: 6/10

Breakdown:
+ 3 points: Aligns with IaC philosophy
+ 2 points: Complements existing microvm.nix well
+ 1 point: Professional VM features
+ 0 points: No clear Windows VM need (currently)
- 0 points: No downsides (complementary addition)
```

## Cost-Benefit Analysis

### Costs

**Implementation Time:**

- Phase 1 (Setup): 2 hours
- Phase 2 (VMs): 3 hours
- Phase 3 (Integration): 2 hours
- **Total**: 4-7 hours

**Ongoing Maintenance:**

- Minimal (VMs defined in config)
- Update VM definitions as needed
- Keep NixVirt flake input updated
- **Estimate**: <1 hour/month

**Complexity:**

- Adds another virtualization system
- Requires understanding libvirt concepts
- Must manage VM lifecycle
- **Impact**: LOW (well-documented with templates)

**Disk Space:**

- VM images can be large (50-100GB per Windows VM)
- Storage pools need space
- **Impact**: MEDIUM on P620 (plan accordingly)

### Benefits

**If You Need Windows VMs:**

- ✅ **Time savings**: Declarative setup vs manual configuration
- ✅ **Reproducibility**: Version-controlled VM definitions
- ✅ **Consistency**: Same VM config across rebuilds
- ✅ **Professional features**: Secure Boot, TPM, full QEMU
- **Value**: **HIGH** (8-10 hours saved per Windows VM)

**If You Want Professional VMs:**

- ✅ **Feature completeness**: All QEMU/KVM capabilities
- ✅ **IaC alignment**: Fits your infrastructure philosophy
- ✅ **Multi-host coordination**: Manage VMs across hosts
- **Value**: **MEDIUM** (nice to have, not critical)

**If You Don't Need VMs Beyond microvm.nix:**

- **Value**: **NONE** (wasted implementation time)

## Alternatives to Consider

### Alternative 1: Just Use virt-manager

**Instead of NixVirt**, use virt-manager GUI for occasional VMs:

```nix
# Simple virt-manager setup
programs.virt-manager.enable = true;
virtualisation.libvirtd.enable = true;
```

**Pros:**

- Much simpler (5 minutes setup)
- Visual interface (easier for occasional use)
- Full feature access immediately

**Cons:**

- Not infrastructure-as-code
- Manual configuration
- No version control
- Not reproducible

**Best for**: Occasional VM needs, infrequent Windows testing

### Alternative 2: Keep microvm.nix Only

**Skip libvirt VMs entirely**, use only microvm.nix:

**Pros:**

- Simpler infrastructure
- One virtualization system
- Lightweight and fast

**Cons:**

- No Windows VM support
- Limited to NixOS guests
- No Secure Boot/TPM

**Best for**: NixOS-only workflows, no Windows needs

### Alternative 3: Hybrid Approach (RECOMMENDED)

**Use NixVirt for declarative VMs + virt-manager for ad-hoc:**

```nix
# Declare long-lived VMs in NixVirt
features.virtualization.nixvirt.enable = true;

# Keep virt-manager for quick tests
programs.virt-manager.enable = true;
```

**Pros:**

- Best of both worlds
- IaC for permanent VMs
- GUI for temporary testing
- Flexible approach

**Cons:**

- Two management methods
- Slight complexity increase

**Best for**: Your use case (professional + flexible)

## Recommendation

### ✅ **IMPLEMENT - If You Need Windows VMs**

**Conditions:**

- You need Windows VM support
- You value infrastructure-as-code
- You want professional VM features
- You have 4-7 hours for implementation

**Expected ROI**: High - saves time on every Windows VM setup

### ⚠️ **DEFER - If Windows VMs Are "Nice to Have"**

**Conditions:**

- No immediate Windows VM need
- Uncertain about future requirements
- Limited time for implementation
- Prefer simpler infrastructure

**Suggested approach**: Close issue with "defer pending specific need"

### ❌ **SKIP - If You Don't Need VMs Beyond microvm.nix**

**Conditions:**

- NixOS-only workflows
- microvm.nix meets all needs
- No Windows development
- Prefer minimal complexity

**Suggested approach**: Close issue as "not needed"

## Implementation Roadmap (If Proceeding)

### Quick Start (2 hours) - Minimal Viable Implementation

```bash
# 1. Add NixVirt to flake inputs (FlakeHub!)
# 2. Create basic module
# 3. Enable on P620
# 4. Test with ONE Linux VM
# 5. Verify with: virsh list --all
```

### Full Implementation (7 hours) - Production Ready

```bash
# Phase 1: Core Setup (2h)
- Add NixVirt to flake.nix
- Create modules/virtualization/nixvirt.nix
- Enable on P620
- Test build: just test-host p620

# Phase 2: VM Creation (3h)
- Create test Linux VM
- Create Windows 11 VM (if needed)
- Configure networking
- Set up storage pools

# Phase 3: Integration (2h)
- Document VMs in config
- Create usage guide
- Test deployment: just p620
- Update roadmap
```

### Success Criteria

```bash
# After implementation, you should be able to:
1. Define VMs in Nix configuration
2. Deploy VMs with: just p620
3. Start VMs with: virsh start VM-NAME
4. Version control all VM definitions
5. Reproduce VMs on any rebuild
```

## When to Reconsider

**Implement NixVirt if you:**

- Start Windows development
- Need cross-platform testing
- Require enterprise VM features
- Want professional virtualization

**Skip NixVirt if you:**

- Never need Windows VMs
- Prefer virt-manager simplicity
- Only need NixOS VMs (keep microvm.nix)
- Want to minimize complexity

## Conclusion

### For Your Infrastructure

**Analysis:**

- You have strong IaC culture ✅
- You already use microvm.nix ✅
- You have suitable hardware (P620) ✅
- **BUT**: No clear Windows VM requirement ⚠️

**Recommendation**: **⚠️ DEFER pending specific use case**

**Rationale:**

1. **No immediate need**: No Windows development mentioned
2. **Time investment**: 4-7 hours better spent elsewhere
3. **Alternative exists**: virt-manager for ad-hoc needs
4. **microvm.nix sufficient**: Current setup meets NixOS VM needs

**Suggested Action:**

```bash
# Close issue #8 with comment:
"Evaluated - strong alignment with IaC philosophy and complements
microvm.nix well. However, no current Windows VM requirement.

Decision: DEFER until specific Windows VM need arises.

If Windows development becomes necessary:
- Implementation time: 4-7 hours
- Strong ROI for declarative Windows VMs
- Aligns with existing infrastructure patterns

Alternative: Use virt-manager for occasional VM needs."
```

**When to Reconsider:**

- Windows development project starts
- Cross-platform testing needed
- Enterprise compatibility requirements
- Professional VM features required

## References

- [GitHub: NixVirt Repository](https://github.com/AshleyYakeley/NixVirt) - 293 stars, active development
- [FlakeHub: NixVirt Releases](https://flakehub.com/f/AshleyYakeley/NixVirt) - **Use this, not GitHub master**
- [NixOS Discourse: NixVirt Announcement](https://discourse.nixos.org/t/nixvirt-manage-virtual-machines/39305)
- [NixOS Wiki: Libvirt](https://nixos.wiki/wiki/Libvirt) - General libvirt guide
- [NixOS Wiki: Virt-manager](https://nixos.wiki/wiki/Virt-manager) - Alternative GUI approach
