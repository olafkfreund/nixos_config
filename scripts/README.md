# NixOS Utility Scripts

This directory contains utility scripts for managing and working with your NixOS system configuration.

## Available Scripts

### check-nixos-updates.sh

Checks for updates to your NixOS flake inputs and displays them in a table format.

**Usage:**
```bash
./check-nixos-updates.sh
```

**Features:**
- Creates a temporary copy of your configuration to check for updates
- Shows a formatted table of all inputs with their current and latest versions
- Color-coded output to easily identify changed versions
- Displays a count of updatable packages
- Shows commands for how to apply updates

**Example output:**
```
Input                    Current        Latest         URL
======================== =============== =============== ==================================================
nixpkgs                  83d4771af0c    91b9335eadb    github:nixos/nixpkgs/nixos-unstable
home-manager            17198719a393    495bc7322c84    github:nix-community/home-manager
```

### toggle-vfio.sh

A utility for switching PCI devices between VFIO (for VM passthrough) and host drivers without rebooting.

**Usage:**
```bash
sudo ./toggle-vfio.sh <PCI_ADDRESS> <HOST_DRIVER> [to-host|to-vm]
```

**Parameters:**
- `PCI_ADDRESS`: The PCI address of the device (e.g., 0000:01:00.0)
- `HOST_DRIVER`: The name of the host driver (e.g., amdgpu, nvidia, etc.)
- `[to-host|to-vm]`: Optional direction, will toggle if not specified

**Examples:**
```bash
# Switch a GPU from VFIO to the host driver
sudo ./toggle-vfio.sh 0000:01:00.0 amdgpu to-host

# Switch a GPU from host to VFIO for VM use
sudo ./toggle-vfio.sh 0000:01:00.0 amdgpu to-vm

# Toggle current state (will switch to opposite of current binding)
sudo ./toggle-vfio.sh 0000:01:00.0 amdgpu
```

**How it works:**
1. Identifies the current driver binding for the specified device
2. Unbinds the device from its current driver
3. Updates driver IDs in the sysfs interface
4. Binds the device to the requested driver
5. Verifies and displays the result

**Notes:**
- Requires root permissions due to sysfs modifications
- You may need to restart related services after driver switching
- For GPUs, you might need to restart your display server after switching back to the host

## Adding New Scripts

When adding new scripts to this directory:
1. Ensure they follow similar structure and error handling patterns
2. Add documentation to this README.md
3. Make your scripts executable with `chmod +x script-name.sh`

```bash
# Assuming device PCI address is 0000:01:00.0
# 1. Get the IOMMU group
IOMMU_GROUP=$(readlink /sys/bus/pci/devices/0000:01:00.0/iommu_group | basename)

# 2. Unbind from VFIO
echo "0000:01:00.0" > /sys/bus/pci/drivers/vfio-pci/unbind

# 3. Remove device ID from VFIO
DEVICE_ID=$(lspci -n -s 0000:01:00.0 | awk '{print $3}')
echo "$DEVICE_ID" > /sys/bus/pci/drivers/vfio-pci/remove_id

# 4. Rescan to bind to the host driver
echo "1" > /sys/bus/pci/devices/0000:01:00.0/rescan

# Or explicitly bind to the original driver (e.g., for a GPU)
echo "0000:01:00.0" > /sys/bus/pci/drivers/amdgpu/bind   # For AMD GPU
# OR
echo "0000:01:00.0" > /sys/bus/pci/drivers/nvidia/bind   # For NVIDIA GPU
```
```bash
# Assuming device PCI address is 0000:01:00.0
# 1. Unbind from current driver (e.g., amdgpu)
echo "0000:01:00.0" > /sys/bus/pci/drivers/amdgpu/unbind

# 2. Get the vendor and device ID
DEVICE_ID=$(lspci -n -s 0000:01:00.0 | awk '{print $3}')

# 3. Add ID to VFIO
echo "$DEVICE_ID" > /sys/bus/pci/drivers/vfio-pci/new_id
```