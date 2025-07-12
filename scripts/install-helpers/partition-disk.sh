#!/bin/bash
# Disk Partitioning Helper for NixOS Installation
# Creates partitions based on parsed hardware configuration

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_step() {
    echo -e "\n${BLUE}→ $1${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

usage() {
    echo "Usage: $0 <target_disk> <config_json>"
    echo "Example: $0 /dev/nvme0n1 '{\"partition_scheme\":{...}}'"
    exit 1
}

wipe_disk() {
    local disk="$1"
    
    print_step "Wiping disk $disk..."
    
    # Unmount any mounted partitions
    for mount in $(mount | grep "^$disk" | awk '{print $3}' | sort -r); do
        print_warning "Unmounting $mount"
        umount "$mount" || true
    done
    
    # Deactivate any LVM/LUKS
    if command -v vgchange >/dev/null 2>&1; then
        vgchange -an || true
    fi
    
    if command -v cryptsetup >/dev/null 2>&1; then
        for mapper in /dev/mapper/*; do
            if [[ -e "$mapper" && "$mapper" != "/dev/mapper/control" ]]; then
                cryptsetup close "$(basename "$mapper")" || true
            fi
        done
    fi
    
    # Zero out the beginning and end of the disk
    dd if=/dev/zero of="$disk" bs=1M count=100 status=progress 2>/dev/null || true
    dd if=/dev/zero of="$disk" bs=1M seek=$(($(blockdev --getsz "$disk") * 512 / 1024 / 1024 - 100)) count=100 status=progress 2>/dev/null || true
    
    # Clear partition table
    wipefs -a "$disk" || true
    
    print_success "Disk wiped"
}

create_gpt_table() {
    local disk="$1"
    
    print_step "Creating GPT partition table on $disk..."
    
    parted -s "$disk" mklabel gpt
    
    print_success "GPT partition table created"
}

create_partitions() {
    local disk="$1"
    local config_data="$2"
    
    print_step "Creating partitions..."
    
    local partitions
    partitions=$(echo "$config_data" | jq -c '.partition_scheme.partitions[]')
    
    local partition_num=1
    local current_start=1
    
    while IFS= read -r partition; do
        local mount_point size_mb fstype label
        mount_point=$(echo "$partition" | jq -r '.mount')
        size_mb=$(echo "$partition" | jq -r '.size_mb')
        fstype=$(echo "$partition" | jq -r '.fstype')
        label=$(echo "$partition" | jq -r '.label // "part${partition_num}"')
        
        print_step "Creating partition $partition_num: $mount_point ($fstype)"
        
        local end_mb
        if [[ "$size_mb" == "remaining" ]]; then
            end_mb="100%"
        else
            end_mb=$((current_start + size_mb))
        fi
        
        # Create partition
        parted -s "$disk" mkpart "$label" "${current_start}MiB" "${end_mb}"
        
        # Set partition type
        case "$fstype" in
            "vfat")
                if [[ "$mount_point" == "/boot" ]]; then
                    parted -s "$disk" set "$partition_num" esp on
                fi
                ;;
            "swap")
                parted -s "$disk" set "$partition_num" swap on
                ;;
        esac
        
        if [[ "$size_mb" != "remaining" ]]; then
            current_start=$((end_mb + 1))
        fi
        
        partition_num=$((partition_num + 1))
    done <<< "$partitions"
    
    # Inform kernel of partition changes
    partprobe "$disk"
    sleep 2
    
    print_success "Partitions created"
}

format_partitions() {
    local disk="$1"
    local config_data="$2"
    
    print_step "Formatting partitions..."
    
    local partitions
    partitions=$(echo "$config_data" | jq -c '.partition_scheme.partitions[]')
    
    local partition_num=1
    
    while IFS= read -r partition; do
        local mount_point fstype label
        mount_point=$(echo "$partition" | jq -r '.mount')
        fstype=$(echo "$partition" | jq -r '.fstype')
        label=$(echo "$partition" | jq -r '.label // "part${partition_num}"')
        
        # Determine partition device
        local part_device
        if [[ "$disk" =~ nvme ]]; then
            part_device="${disk}p${partition_num}"
        else
            part_device="${disk}${partition_num}"
        fi
        
        print_step "Formatting $part_device as $fstype (label: $label)"
        
        case "$fstype" in
            "ext4")
                mkfs.ext4 -L "$label" -F "$part_device"
                ;;
            "vfat")
                mkfs.fat -F 32 -n "$label" "$part_device"
                ;;
            "swap")
                mkswap -L "$label" "$part_device"
                ;;
            "xfs")
                mkfs.xfs -L "$label" -f "$part_device"
                ;;
            "btrfs")
                mkfs.btrfs -L "$label" -f "$part_device"
                ;;
            *)
                print_warning "Unknown filesystem type: $fstype, skipping format"
                ;;
        esac
        
        partition_num=$((partition_num + 1))
    done <<< "$partitions"
    
    print_success "Partitions formatted"
}

verify_partitions() {
    local disk="$1"
    
    print_step "Verifying partition table..."
    
    parted -s "$disk" print
    lsblk "$disk"
    
    print_success "Partition verification complete"
}

main() {
    if [[ $# -ne 2 ]]; then
        usage
    fi
    
    local target_disk="$1"
    local config_data="$2"
    
    # Verify disk exists
    if [[ ! -e "$target_disk" ]]; then
        print_error "Disk $target_disk does not exist!"
        exit 1
    fi
    
    # Verify config data
    if ! echo "$config_data" | jq -e '.partition_scheme' >/dev/null 2>&1; then
        print_error "Invalid configuration data - missing partition_scheme"
        exit 1
    fi
    
    print_step "Partitioning disk: $target_disk"
    
    # Show current disk state
    print_step "Current disk state:"
    lsblk "$target_disk" || true
    
    # Confirm operation
    echo -e "\n${RED}⚠️  WARNING: This will ERASE all data on $target_disk${NC}"
    read -p "Type 'yes' to continue: " confirm
    if [[ "$confirm" != "yes" ]]; then
        print_warning "Operation cancelled"
        exit 1
    fi
    
    # Perform partitioning steps
    wipe_disk "$target_disk"
    create_gpt_table "$target_disk"
    create_partitions "$target_disk" "$config_data"
    format_partitions "$target_disk" "$config_data"
    verify_partitions "$target_disk"
    
    print_success "Disk partitioning completed successfully!"
}

# Only run main if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi