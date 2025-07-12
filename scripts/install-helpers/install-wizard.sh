#!/bin/bash
# NixOS Installation Wizard
# Automated installation based on existing hardware configurations

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
MOUNT_ROOT="/mnt"

# Logging
LOG_FILE="/tmp/nixos-install.log"
exec 1> >(tee -a "$LOG_FILE")
exec 2>&1

print_header() {
    echo -e "\n${PURPLE}╭─────────────────────────────────────────╮${NC}"
    echo -e "${PURPLE}│        NixOS Installation Wizard       │${NC}"
    echo -e "${PURPLE}╰─────────────────────────────────────────╯${NC}\n"
}

print_step() {
    echo -e "\n${BLUE}→ $1${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

confirm() {
    local prompt="$1"
    local default="${2:-n}"
    local response
    
    if [[ "$default" == "y" ]]; then
        prompt="$prompt [Y/n]: "
    else
        prompt="$prompt [y/N]: "
    fi
    
    read -p "$prompt" response
    response="${response:-$default}"
    
    [[ "$response" =~ ^[Yy]$ ]]
}

show_available_hosts() {
    echo -e "\n${CYAN}Available hosts:${NC}"
    if [[ -d "$CONFIG_DIR/hosts" ]]; then
        for host_dir in "$CONFIG_DIR/hosts"/*; do
            if [[ -d "$host_dir" ]]; then
                local hostname=$(basename "$host_dir")
                echo -e "  • $hostname"
            fi
        done
    fi
    echo
}

detect_disks() {
    print_step "Detecting available disks..."
    
    echo -e "\n${CYAN}Available disks:${NC}"
    lsblk -d -o NAME,SIZE,MODEL | grep -E "^(sd|nvme|vd)" || true
    
    echo -e "\n${CYAN}Detailed disk information:${NC}"
    for disk in /dev/sd[a-z] /dev/nvme[0-9]n[0-9] /dev/vd[a-z]; do
        if [[ -e "$disk" ]]; then
            echo -e "\n${YELLOW}$disk:${NC}"
            fdisk -l "$disk" 2>/dev/null | head -5 || true
        fi
    done
}

auto_detect_target_disk() {
    local config_data="$1"
    
    # Try to find the primary disk based on filesystem entries
    local root_device=$(echo "$config_data" | jq -r '.filesystems["/"].device // empty')
    
    if [[ -n "$root_device" && "$root_device" != "null" ]]; then
        # Extract disk from partition (e.g., /dev/nvme0n1p2 -> /dev/nvme0n1)
        if [[ "$root_device" =~ /dev/disk/by-uuid/ ]]; then
            # Resolve UUID to actual device
            local actual_device=$(readlink -f "$root_device" 2>/dev/null || true)
            if [[ -n "$actual_device" ]]; then
                root_device="$actual_device"
            fi
        fi
        
        # Extract base disk name
        if [[ "$root_device" =~ /dev/(nvme[0-9]+)n[0-9]+p[0-9]+ ]]; then
            echo "/dev/${BASH_REMATCH[1]}n1"
        elif [[ "$root_device" =~ /dev/(sd[a-z])[0-9]+ ]]; then
            echo "/dev/${BASH_REMATCH[1]}"
        elif [[ "$root_device" =~ /dev/(vd[a-z])[0-9]+ ]]; then
            echo "/dev/${BASH_REMATCH[1]}"
        fi
    fi
}

select_target_disk() {
    local suggested_disk="$1"
    
    detect_disks
    
    if [[ -n "$suggested_disk" && -e "$suggested_disk" ]]; then
        echo -e "\n${GREEN}Suggested target disk: $suggested_disk${NC}"
        if confirm "Use suggested disk $suggested_disk for installation?" "y"; then
            echo "$suggested_disk"
            return
        fi
    fi
    
    echo -e "\n${YELLOW}Please select target disk for installation:${NC}"
    local disks=()
    for disk in /dev/sd[a-z] /dev/nvme[0-9]n[0-9] /dev/vd[a-z]; do
        if [[ -e "$disk" ]]; then
            disks+=("$disk")
        fi
    done
    
    if [[ ${#disks[@]} -eq 0 ]]; then
        print_error "No suitable disks found!"
        exit 1
    fi
    
    PS3="Select disk: "
    select disk in "${disks[@]}"; do
        if [[ -n "$disk" ]]; then
            echo "$disk"
            return
        fi
    done
}

show_installation_plan() {
    local hostname="$1"
    local target_disk="$2"
    local config_data="$3"
    
    echo -e "\n${PURPLE}╭─────────────────────────────────────────╮${NC}"
    echo -e "${PURPLE}│           Installation Plan             │${NC}"
    echo -e "${PURPLE}╰─────────────────────────────────────────╯${NC}"
    
    echo -e "\n${CYAN}Host:${NC} $hostname"
    echo -e "${CYAN}Target Disk:${NC} $target_disk"
    echo -e "${CYAN}Disk Size:${NC} $(lsblk -d -n -o SIZE "$target_disk" 2>/dev/null || echo "Unknown")"
    
    echo -e "\n${CYAN}Partitions to create:${NC}"
    echo "$config_data" | jq -r '.partition_scheme.partitions[] | "  \(.mount) -> \(.fstype) (\(.size_mb)MB)"'
    
    echo -e "\n${CYAN}Boot Configuration:${NC}"
    local loader=$(echo "$config_data" | jq -r '.boot.loader // "unknown"')
    local uefi=$(echo "$config_data" | jq -r '.boot.uefi // false')
    echo -e "  Loader: $loader"
    echo -e "  UEFI: $uefi"
    
    echo -e "\n${CYAN}Hardware Modules:${NC}"
    echo "$config_data" | jq -r '.hardware_modules[]? | "  \(.)"' || echo "  None specified"
    
    echo -e "\n${RED}⚠️  WARNING: This will ERASE all data on $target_disk${NC}"
    echo
}

install_host() {
    local hostname="$1"
    
    print_header
    print_step "Starting installation for host: $hostname"
    
    # Check if we're root
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root!"
        exit 1
    fi
    
    # Parse hardware configuration
    print_step "Parsing hardware configuration..."
    local config_data
    if ! config_data=$("$SCRIPT_DIR/parse-hardware-config.py" "$hostname"); then
        print_error "Failed to parse hardware configuration for $hostname"
        show_available_hosts
        exit 1
    fi
    
    print_success "Hardware configuration parsed"
    
    # Auto-detect target disk
    print_step "Auto-detecting target disk..."
    local suggested_disk
    suggested_disk=$(auto_detect_target_disk "$config_data")
    
    # Select target disk
    local target_disk
    target_disk=$(select_target_disk "$suggested_disk")
    
    if [[ ! -e "$target_disk" ]]; then
        print_error "Selected disk $target_disk does not exist!"
        exit 1
    fi
    
    # Show installation plan
    show_installation_plan "$hostname" "$target_disk" "$config_data"
    
    # Final confirmation
    if ! confirm "Proceed with installation? This will ERASE $target_disk" "n"; then
        print_warning "Installation cancelled by user"
        exit 0
    fi
    
    # Partition the disk
    print_step "Partitioning disk $target_disk..."
    if ! "$SCRIPT_DIR/partition-disk.sh" "$target_disk" "$config_data"; then
        print_error "Failed to partition disk"
        exit 1
    fi
    print_success "Disk partitioned successfully"
    
    # Mount filesystems
    print_step "Mounting filesystems..."
    if ! "$SCRIPT_DIR/mount-filesystems.sh" "$config_data"; then
        print_error "Failed to mount filesystems"
        exit 1
    fi
    print_success "Filesystems mounted"
    
    # Copy hardware configuration
    print_step "Copying hardware configuration..."
    mkdir -p "${MOUNT_ROOT}/etc/nixos"
    
    local hw_config_source
    hw_config_source=$(echo "$config_data" | jq -r '.source_file')
    cp "$hw_config_source" "${MOUNT_ROOT}/etc/nixos/hardware-configuration.nix"
    print_success "Hardware configuration copied"
    
    # Install NixOS
    print_step "Installing NixOS..."
    echo "Running: nixos-install --flake ${CONFIG_DIR}#${hostname}"
    
    if nixos-install --flake "${CONFIG_DIR}#${hostname}" --no-root-password; then
        print_success "NixOS installation completed!"
    else
        print_error "NixOS installation failed!"
        exit 1
    fi
    
    # Set root password
    print_step "Setting root password..."
    echo "Please set a root password for the new system:"
    nixos-enter --root "$MOUNT_ROOT" -c "passwd root"
    
    # Installation complete
    echo -e "\n${GREEN}╭─────────────────────────────────────────╮${NC}"
    echo -e "${GREEN}│     Installation Completed Successfully │${NC}"
    echo -e "${GREEN}╰─────────────────────────────────────────╯${NC}"
    
    echo -e "\n${CYAN}Next steps:${NC}"
    echo "1. Remove the installation media"
    echo "2. Reboot the system"
    echo "3. Log in as root with the password you just set"
    echo "4. Update user passwords as needed"
    
    if confirm "Reboot now?" "n"; then
        print_step "Rebooting..."
        reboot
    fi
}

main() {
    if [[ $# -eq 0 ]]; then
        print_header
        echo "Usage: $0 <hostname>"
        echo
        show_available_hosts
        exit 1
    fi
    
    local hostname="$1"
    install_host "$hostname"
}

# Only run main if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi