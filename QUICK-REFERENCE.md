# NixOS Structure Refactoring - Quick Reference

> **Current Branch**: `feature/nixos-structure-refactor`
> **Status**: Planning Complete, Ready for Phase 1

## 📁 **New Structure Overview**

```bash
nixos-config/                    # Root (reduced from 28 to 10 directories)
├── flake.nix                   # Main flake
├── lib/                        # ✅ Library functions
├── pkgs/                       # ✅ Custom packages
├── modules/                    # 🔄 REORGANIZED
│   ├── nixos/                  # 🆕 System modules
│   │   ├── core/               # Headless-compatible
│   │   ├── desktop/            # GUI-only
│   │   ├── services/           # System services
│   │   ├── development/        # Dev tools
│   │   └── hardware/           # Hardware-specific
│   └── home-manager/           # 🆕 User modules
│       ├── profiles/           # Role-based configs
│       ├── programs/           # Program configs
│       └── desktop/            # Desktop configs
├── hosts/                      # 🔄 CATEGORIZED
│   ├── servers/                # 🆕 Headless servers
│   │   ├── dex5550/           # Monitoring server
│   │   └── p510/              # Media server (converted)
│   ├── workstations/          # 🆕 Desktop systems
│   │   └── p620/              # Primary workstation
│   ├── laptops/               # 🆕 Mobile devices
│   │   ├── razer/             # Intel/NVIDIA laptop
│   │   └── samsung/           # Intel laptop
│   ├── templates/             # 🆕 Host templates
│   └── common/                # ✅ Shared configs
├── home/                      # 🔄 PROFILE-BASED
│   ├── profiles/              # 🆕 Role configs
│   │   ├── server-admin/      # Minimal headless
│   │   ├── developer/         # Dev-focused
│   │   ├── desktop-user/      # Full GUI
│   │   └── laptop-user/       # Mobile-optimized
│   └── modules/               # ✅ Home modules
├── overlays/                  # 🆕 Nixpkgs overlays
├── assets/                    # 🆕 Static resources
│   ├── wallpapers/
│   ├── themes/
│   └── icons/
├── secrets/                   # ✅ Encrypted secrets
├── scripts/                   # ✅ Automation
└── docs/                      # ✅ Documentation
```

## 🎯 **Host Categories**

### **Servers** (Headless)

- **DEX5550**: Monitoring server (Prometheus/Grafana)
- **P510**: Media server (Plex/NZBGet) - **TO BE CONVERTED**

### **Workstations** (Full Desktop)

- **P620**: Primary workstation (AMD/ROCm, AI development)

### **Laptops** (Mobile)

- **Razer**: Intel/NVIDIA laptop
- **Samsung**: Intel laptop

## 🏠 **Home Manager Profiles**

### **server-admin**

- Minimal shell configuration
- Essential admin tools only
- No GUI components

### **developer**

- Full development environment
- Language tools and editors
- Development workflow tools

### **desktop-user**

- Complete desktop environment
- GUI applications and theming
- Media and productivity tools

### **laptop-user**

- Power-optimized configurations
- Mobile-specific applications
- Battery-conscious settings

## 📋 **Current Phase Status**

| Phase | Status     | Description                        |
| ----- | ---------- | ---------------------------------- |
| 1     | 🟡 Pending | Directory structure & core modules |
| 2     | 🟡 Pending | Host category reorganization       |
| 3     | 🟡 Pending | Home Manager profile system        |
| 4     | 🟡 Pending | Asset consolidation & cleanup      |
| 5     | 🟡 Pending | P510 server conversion             |
| 6     | 🟡 Pending | Final validation & documentation   |

## 🚀 **Next Steps**

1. **Review the full plan**: See `RESTRUCTURING-PLAN.md`
2. **Start Phase 1**: Begin directory structure creation
3. **Test incrementally**: Validate each phase before proceeding
4. **Monitor progress**: Update todo items as work progresses

## 📚 **Key Files**

- **`RESTRUCTURING-PLAN.md`**: Complete implementation plan
- **`CLAUDE.md`**: Project context and instructions
- **`flake.nix`**: Main configuration entry point
- **`lib/host-types.nix`**: Host template definitions

## 🔄 **Migration Benefits**

- ✅ Clear server/workstation/laptop boundaries
- ✅ GUI components cleanly separated from headless
- ✅ Profile-based home manager configurations
- ✅ Best practices folder structure
- ✅ Reduced root directory clutter (28 → 10 dirs)
- ✅ P510 converted to efficient headless server
- ✅ Maintainable, scalable architecture

---

**Ready to begin Phase 1!** 🚀
