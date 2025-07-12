#!/bin/bash
# Mount Filesystems Helper for NixOS Installation
# Mounts filesystems based on parsed hardware configuration

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

MOUNT_ROOT="/mnt"

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
    echo "Usage: $0 <config_json>"
    echo "Example: $0 '{\"partition_scheme\":{...}}'"
    exit 1
}

find_partition_device() {
    local label="$1"
    local fstype="$2"
    
    # Try to find by label first
    if [[ -e "/dev/disk/by-label/$label" ]]; then
        echo "/dev/disk/by-label/$label"
        return 0
    fi
    
    # Try to find by filesystem UUID (if available)
    for device in /dev/sd* /dev/nvme* /dev/vd*; do
        if [[ -e "$device" ]]; then
            local device_fstype
            device_fstype=$(blkid -o value -s TYPE "$device" 2>/dev/null || echo "")
            local device_label
            device_label=$(blkid -o value -s LABEL "$device" 2>/dev/null || echo "")
            
            if [[ "$device_fstype" == "$fstype" && "$device_label" == "$label" ]]; then
                echo "$device"
                return 0
            fi
        fi
    done
    
    return 1
}

mount_filesystem() {
    local mount_point="$1"
    local device="$2"
    local fstype="$3"
    local options="$4"
    
    local full_mount_path
    if [[ "$mount_point" == "/" ]]; then
        full_mount_path="$MOUNT_ROOT"
    else
        full_mount_path="${MOUNT_ROOT}${mount_point}"
    fi
    
    print_step "Mounting $device -> $full_mount_path ($fstype)"
    
    # Create mount point
    mkdir -p "$full_mount_path"
    
    # Mount with options
    if [[ -n "$options" ]]; then
        mount -t "$fstype" -o "$options" "$device" "$full_mount_path"
    else
        mount -t "$fstype" "$device" "$full_mount_path"
    fi
    
    print_success "Mounted $mount_point"
}

unmount_all() {
    print_step "Unmounting any existing mounts under $MOUNT_ROOT..."
    
    # Unmount in reverse order (deepest first)
    for mount in $(mount | grep "^.* ${MOUNT_ROOT}" | awk '{print $3}' | sort -r); do
        print_warning "Unmounting $mount"
        umount "$mount" || true
    done
    
    print_success "Cleanup complete"
}

mount_filesystems() {
    local config_data="$1"
    
    # First unmount any existing mounts
    unmount_all
    
    # Get partitions sorted by mount depth (root first, then subdirectories)
    local partitions
    partitions=$(echo "$config_data" | jq -c '.partition_scheme.partitions[] | select(.mount != "" and .fstype != "swap")' | \
        jq -s 'sort_by(.mount | length)')
    
    local mounted_devices=()
    
    while IFS= read -r partition; do
        local mount_point fstype label
        mount_point=$(echo "$partition" | jq -r '.mount')
        fstype=$(echo "$partition" | jq -r '.fstype')
        label=$(echo "$partition" | jq -r '.label')
        
        # Skip swap partitions
        if [[ "$fstype" == "swap" ]]; then
            continue
        fi
        
        # Find the actual device
        local device
        if ! device=$(find_partition_device "$label" "$fstype"); then
            print_error "Could not find device for mount point $mount_point (label: $label, fstype: $fstype)"
            continue
        fi
        
        # Extract mount options from original config if available
        local options=""
        if echo "$config_data" | jq -e ".filesystems[\"$mount_point\"].options" >/dev/null 2>&1; then
            options=$(echo "$config_data" | jq -r ".filesystems[\"$mount_point\"].options | join(\",\")")
        fi
        
        # Mount the filesystem
        if mount_filesystem "$mount_point" "$device" "$fstype" "$options"; then
            mounted_devices+=("$device:$mount_point")
        else
            print_error "Failed to mount $mount_point"
            exit 1
        fi
        
    done <<< "$partitions"
    
    # Activate swap partitions
    print_step "Activating swap partitions..."
    local swap_partitions
    swap_partitions=$(echo "$config_data" | jq -c '.partition_scheme.partitions[] | select(.fstype == "swap")')
    
    while IFS= read -r partition; do
        local label
        label=$(echo "$partition" | jq -r '.label')
        
        local device
        if device=$(find_partition_device "$label" "swap"); then
            print_step "Activating swap on $device"
            swapon "$device"
            print_success "Swap activated"
        else
            print_warning "Could not find swap device with label: $label"
        fi
    done <<< "$swap_partitions"
    
    # Show mounted filesystems
    print_step "Mount summary:"
    mount | grep "$MOUNT_ROOT" || echo "No mounts found under $MOUNT_ROOT"
    
    print_step "Disk usage:"
    df -h | grep "$MOUNT_ROOT" || echo "No disk usage info available"
}

verify_mounts() {
    print_step "Verifying mount points..."
    
    # Check that root is mounted
    if ! mount | grep -q "$MOUNT_ROOT "; then
        print_error "Root filesystem not mounted at $MOUNT_ROOT"
        return 1
    fi
    
    # Check that boot is mounted (if it should be)
    if [[ -d "$MOUNT_ROOT/boot" ]]; then
        if ! mount | grep -q "$MOUNT_ROOT/boot "; then
            print_warning "Boot filesystem not mounted (this may be normal for some configurations)"
        fi
    fi
    
    print_success "Mount verification complete"
}

main() {
    if [[ $# -ne 1 ]]; then
        usage
    fi
    
    local config_data="$1"
    
    # Verify config data
    if ! echo "$config_data" | jq -e '.partition_scheme' >/dev/null 2>&1; then
        print_error "Invalid configuration data - missing partition_scheme"
        exit 1
    fi
    
    print_step "Mounting filesystems for installation..."
    
    mount_filesystems "$config_data"
    verify_mounts
    
    print_success "Filesystem mounting completed successfully!"
    
    echo -e "\n${GREEN}Ready for NixOS installation at $MOUNT_ROOT${NC}"
}

# Cleanup function for script termination
cleanup() {
    if [[ "${1:-}" != "0" ]]; then
        print_warning "Script interrupted, cleaning up..."
        unmount_all || true
    fi
}

trap 'cleanup $?' EXIT

# Only run main if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi