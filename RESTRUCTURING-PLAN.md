# NixOS Infrastructure Restructuring Plan

> **Branch**: `feature/nixos-structure-refactor`
> **Started**: 2025-09-02
> **Goal**: Reorganize NixOS configuration following best practices with clear server/workstation/laptop separation

## 🎯 **Project Objectives**

1. **Clear Host Categories**: Organize hosts into server/workstation/laptop with appropriate templates
2. **GUI/Headless Separation**: Clean separation of desktop components from core system
3. **Best Practices Structure**: Follow NixOS community standards and nixpkgs conventions
4. **Home Manager Organization**: Profile-based user configurations
5. **P510 Server Conversion**: Convert P510 from workstation to headless media server
6. **Maintainable Architecture**: Reduce duplication and improve maintainability

## 📋 **Implementation Phases**

### **Phase 1: Directory Structure & Core Modules** ⏳

**Timeline**: Week 1
**Status**: 🟡 Pending

#### Tasks

- [ ] **1.1** Create new directory structure
  - [ ] Create `modules/nixos/{core,desktop,services,development,hardware}/`
  - [ ] Create `modules/home-manager/{profiles,programs,services,desktop}/`
  - [ ] Create `hosts/{servers,workstations,laptops,templates,common}/`
  - [ ] Create `overlays/`, `assets/` directories

- [ ] **1.2** Move and reorganize core modules
  - [ ] Move GUI-independent modules to `modules/nixos/core/`
  - [ ] Move desktop modules to `modules/nixos/desktop/`
  - [ ] Move service modules to `modules/nixos/services/`
  - [ ] Update all import paths

- [ ] **1.3** Create module index files
  - [ ] Update `modules/nixos/default.nix` with new structure
  - [ ] Create `modules/home-manager/default.nix`
  - [ ] Update main `modules/default.nix`

- [ ] **1.4** Test core functionality
  - [ ] Validate DEX5550 (server) still builds
  - [ ] Validate P620 (workstation) still builds
  - [ ] Fix any broken imports

#### Success Criteria

- ✅ New directory structure created
- ✅ Core modules moved without breaking builds
- ✅ All imports updated and working
- ✅ DEX5550 and P620 build successfully

---

### **Phase 2: Host Category Reorganization** ⏳

**Timeline**: Week 2
**Status**: 🟡 Pending
**Dependencies**: Phase 1 complete

#### Tasks

- [ ] **2.1** Create host templates
  - [ ] Create `hosts/templates/server.nix` (headless template)
  - [ ] Create `hosts/templates/workstation.nix` (full desktop template)
  - [ ] Create `hosts/templates/laptop.nix` (mobile template)
  - [ ] Update `lib/host-types.nix` with new templates

- [ ] **2.2** Reorganize existing hosts
  - [ ] Move DEX5550 to `hosts/servers/dex5550/`
  - [ ] Move P620 to `hosts/workstations/p620/`
  - [ ] Move Razer to `hosts/laptops/razer/`
  - [ ] Move Samsung to `hosts/laptops/samsung/`
  - [ ] Keep P510 in current location (convert in Phase 5)

- [ ] **2.3** Update host configurations
  - [ ] Split host configs into logical files (hardware.nix, services.nix, etc.)
  - [ ] Update import paths to use new template system
  - [ ] Ensure feature flags work with new structure

- [ ] **2.4** Update flake.nix
  - [ ] Update host paths in flake.nix
  - [ ] Test host building with new paths
  - [ ] Update automation scripts (justfile) with new paths

#### Success Criteria

- ✅ All hosts organized by category
- ✅ Host templates working and tested
- ✅ All hosts build successfully in new locations
- ✅ Justfile automation updated

---

### **Phase 3: Home Manager Profile System** ⏳

**Timeline**: Week 3
**Status**: 🟡 Pending
**Dependencies**: Phase 2 complete

#### Tasks

- [ ] **3.1** Create Home Manager profiles
  - [ ] Create `home/profiles/server-admin/` (minimal headless config)
  - [ ] Create `home/profiles/developer/` (development-focused config)
  - [ ] Create `home/profiles/desktop-user/` (full GUI config)
  - [ ] Create `home/profiles/laptop-user/` (mobile-optimized config)

- [ ] **3.2** Reorganize home modules
  - [ ] Move existing home configurations to appropriate profiles
  - [ ] Create profile-specific module imports
  - [ ] Ensure desktop components only in GUI profiles

- [ ] **3.3** Update host-user mappings
  - [ ] Map DEX5550 users to server-admin profile
  - [ ] Map P620 users to developer + desktop-user profiles
  - [ ] Map laptop users to laptop-user profile
  - [ ] Test profile switching functionality

- [ ] **3.4** Profile inheritance system
  - [ ] Implement profile composition (e.g., developer + desktop-user)
  - [ ] Create profile-specific feature flags
  - [ ] Test profile combinations

#### Success Criteria

- ✅ Profile-based home manager system working
- ✅ Users mapped to appropriate profiles
- ✅ Desktop components cleanly separated from server profiles
- ✅ Profile inheritance working correctly

---

### **Phase 4: Asset Consolidation & Cleanup** ⏳

**Timeline**: Week 4
**Status**: 🟡 Pending
**Dependencies**: Phase 3 complete

#### Tasks

- [ ] **4.1** Consolidate scattered directories
  - [ ] Move `wallpapers/` → `assets/wallpapers/`
  - [ ] Move `themes/` → `assets/themes/`
  - [ ] Move `icons/` → `assets/icons/`
  - [ ] Move `certs/` → `assets/certificates/`

- [ ] **4.2** Merge duplicate directories
  - [ ] Merge `doc/` and `docs/` → `docs/`
  - [ ] Consolidate `Users/` and `users/` → remove, use host configs
  - [ ] Merge `roles/` → `home/profiles/`
  - [ ] Review and merge other duplicates

- [ ] **4.3** Remove obsolete directories
  - [ ] Remove `apps/` (moved to modules)
  - [ ] Remove `benchmark-results/` (move to docs or gitignore)
  - [ ] Remove `migration/` (temporary)
  - [ ] Remove `optimization/` (move to docs)
  - [ ] Remove `patches/` (move to overlays)
  - [ ] Remove `shells/` (moved to modules)
  - [ ] Remove `templates/` (moved to hosts/templates)
  - [ ] Remove `vm/` (moved to modules or docs)

- [ ] **4.4** Update all references
  - [ ] Update import paths throughout codebase
  - [ ] Update documentation links
  - [ ] Update automation scripts
  - [ ] Update .gitignore for new structure

#### Success Criteria

- ✅ Root directory reduced from 28 to ~10 directories
- ✅ All assets properly organized
- ✅ No broken imports or references
- ✅ Clean, maintainable structure

---

### **Phase 5: P510 Server Conversion** ⏳

**Timeline**: Week 5 (parallel with Phase 4)
**Status**: 🟡 Pending
**Dependencies**: Phase 2 complete

#### Tasks

- [ ] **5.1** Prepare P510 server configuration
  - [ ] Create `hosts/servers/p510/` directory
  - [ ] Copy current P510 config as baseline
  - [ ] Remove all desktop/GUI components
  - [ ] Configure as headless media server

- [ ] **5.2** Media server setup
  - [ ] Configure Plex server (headless)
  - [ ] Configure NZBGet/download services
  - [ ] Configure storage management
  - [ ] Configure remote access (SSH, web interfaces)

- [ ] **5.3** Monitoring integration
  - [ ] Configure as monitoring client to DEX5550
  - [ ] Add media-specific monitoring exporters
  - [ ] Test monitoring dashboards

- [ ] **5.4** Test conversion
  - [ ] Test headless operation
  - [ ] Verify media services work
  - [ ] Test remote administration
  - [ ] Performance validation

#### Success Criteria

- ✅ P510 running as headless server
- ✅ All media services operational
- ✅ Remote administration working
- ✅ Monitoring integration successful

---

### **Phase 6: Final Validation & Documentation** ⏳

**Timeline**: Week 6
**Status**: 🟡 Pending
**Dependencies**: All previous phases complete

#### Tasks

- [ ] **6.1** Comprehensive testing
  - [ ] Build all hosts with new structure
  - [ ] Deploy test configurations to each host type
  - [ ] Validate all services and functionality
  - [ ] Performance regression testing

- [ ] **6.2** Update documentation
  - [ ] Update README.md with new structure
  - [ ] Create ARCHITECTURE.md documentation
  - [ ] Update deployment guides
  - [ ] Create troubleshooting documentation

- [ ] **6.3** Migration guides
  - [ ] Document the restructuring changes
  - [ ] Create templates for future hosts
  - [ ] Update development workflows

- [ ] **6.4** Final cleanup
  - [ ] Remove temporary files
  - [ ] Clean up git history if needed
  - [ ] Tag release version

#### Success Criteria

- ✅ All hosts building and deploying successfully
- ✅ Comprehensive documentation updated
- ✅ No functionality regression
- ✅ Clean, maintainable codebase

---

## 📊 **Progress Tracking**

### **Overall Progress**: 0% Complete

| Phase   | Status     | Progress | Timeline | Dependencies |
| ------- | ---------- | -------- | -------- | ------------ |
| Phase 1 | 🟡 Pending | 0%       | Week 1   | None         |
| Phase 2 | 🟡 Pending | 0%       | Week 2   | Phase 1      |
| Phase 3 | 🟡 Pending | 0%       | Week 3   | Phase 2      |
| Phase 4 | 🟡 Pending | 0%       | Week 4   | Phase 3      |
| Phase 5 | 🟡 Pending | 0%       | Week 5   | Phase 2      |
| Phase 6 | 🟡 Pending | 0%       | Week 6   | All phases   |

### **Legend**

- 🔴 **Blocked**: Cannot proceed due to dependencies or issues
- 🟡 **Pending**: Ready to start but not yet begun
- 🔵 **In Progress**: Currently being worked on
- 🟢 **Complete**: Finished and validated

---

## 🚨 **Risk Management**

### **High Risk Items**

1. **Import Path Breakage**: Extensive import path changes could break builds
   - _Mitigation_: Phase-by-phase testing, maintain working branch

2. **P510 Conversion Complexity**: Converting workstation to server is complex
   - _Mitigation_: Thorough testing, backup plan, parallel development

3. **Home Manager Profile Conflicts**: Profile system might conflict with existing configs
   - _Mitigation_: Gradual migration, extensive testing

### **Rollback Plan**

- Each phase has clear success criteria
- Maintain `main` branch as fallback
- Test each phase before proceeding
- Document rollback procedures

---

## 📝 **Notes & Decisions**

### **Architectural Decisions**

- **Module Organization**: NixOS modules separate from Home Manager modules
- **Host Categories**: Physical separation by purpose (server/workstation/laptop)
- **Profile System**: Role-based rather than host-based home configurations
- **Asset Consolidation**: Single assets/ directory for all static resources

### **Important Considerations**

- Maintain backward compatibility where possible
- Preserve all existing functionality
- Follow NixOS community best practices
- Ensure P510 conversion doesn't break media services

### **Future Enhancements**

- Consider auto-detection of host categories
- Implement configuration validation CI
- Add performance benchmarking
- Consider configuration deployment automation

---

**Last Updated**: 2025-09-02
**Next Review**: After Phase 1 completion
