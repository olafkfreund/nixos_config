#!/usr/bin/env bash
# toggle-vfio.sh - Toggle device between VFIO and host driver
# Usage: toggle-vfio.sh <PCI_ADDRESS> <HOST_DRIVER> [to-host|to-vm]

set -e

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root"
  exit 1
fi

if [ "$#" -lt 2 ]; then
  echo "Usage: $0 <PCI_ADDRESS> <HOST_DRIVER> [to-host|to-vm]"
  echo "Example: $0 0000:01:00.0 amdgpu to-host"
  echo "Example: $0 0000:01:00.0 nvidia to-vm"
  exit 1
fi

PCI_ADDRESS="$1"
HOST_DRIVER="$2"
DIRECTION="${3:-toggle}"

# Check if device exists
if [ ! -e "/sys/bus/pci/devices/$PCI_ADDRESS" ]; then
  echo "Error: PCI device $PCI_ADDRESS does not exist"
  exit 1
fi

# Get vendor:device ID
DEVICE_ID=$(lspci -n -s "$PCI_ADDRESS" | awk '{print $3}')
echo "Device ID: $DEVICE_ID"

# Determine current driver
CURRENT_DRIVER=$(lspci -k -s "$PCI_ADDRESS" | grep "Kernel driver in use:" | cut -d: -f2 | xargs)
echo "Current driver: $CURRENT_DRIVER"

# If direction is toggle, determine what to do
if [ "$DIRECTION" = "toggle" ]; then
  if [ "$CURRENT_DRIVER" = "vfio-pci" ]; then
    DIRECTION="to-host"
  else
    DIRECTION="to-vm"
  fi
fi

case "$DIRECTION" in
  to-host)
    echo "Unbinding device from VFIO-PCI..."
    echo "$PCI_ADDRESS" >/sys/bus/pci/drivers/vfio-pci/unbind

    echo "Removing device ID from VFIO-PCI..."
    echo "$DEVICE_ID" >/sys/bus/pci/drivers/vfio-pci/remove_id

    echo "Binding device to $HOST_DRIVER..."
    echo "$PCI_ADDRESS" >/sys/bus/pci/drivers/$HOST_DRIVER/bind
    ;;

  to-vm)
    if [ "$CURRENT_DRIVER" != "vfio-pci" ]; then
      echo "Unbinding device from $CURRENT_DRIVER..."
      echo "$PCI_ADDRESS" >/sys/bus/pci/drivers/$CURRENT_DRIVER/unbind
    fi

    echo "Adding device ID to VFIO-PCI..."
    echo "$DEVICE_ID" >/sys/bus/pci/drivers/vfio-pci/new_id

    # In case it didn't automatically bind
    if [ ! -e "/sys/bus/pci/drivers/vfio-pci/$PCI_ADDRESS" ]; then
      echo "Manually binding to VFIO-PCI..."
      echo "$PCI_ADDRESS" >/sys/bus/pci/drivers/vfio-pci/bind
    fi
    ;;
esac

echo "Done. Current driver:"
lspci -k -s "$PCI_ADDRESS" | grep "Kernel driver in use:"
