#!/usr/bin/env python3
"""
Hardware Configuration Parser for NixOS Live Installer

Parses hardware-configuration.nix to extract:
- Filesystem definitions and mount points
- Boot configuration
- Hardware modules
- Partition requirements

This allows automatic recreation of the same disk layout
during installation.
"""

import re
import json
import sys
import os
from pathlib import Path
from typing import Dict, List, Optional, Tuple


class HardwareConfigParser:
    """Parser for NixOS hardware-configuration.nix files"""
    
    def __init__(self, config_path: str):
        self.config_path = Path(config_path)
        self.config_text = ""
        self.filesystems = {}
        self.boot_config = {}
        self.hardware_modules = []
        
    def load_config(self) -> bool:
        """Load the hardware configuration file"""
        try:
            with open(self.config_path, 'r') as f:
                self.config_text = f.read()
            return True
        except FileNotFoundError:
            print(f"Error: Hardware config not found: {self.config_path}")
            return False
        except Exception as e:
            print(f"Error loading config: {e}")
            return False
    
    def parse_filesystems(self) -> Dict:
        """Parse fileSystems entries from the config"""
        filesystems = {}
        
        # Pattern to match fileSystems entries
        pattern = r'fileSystems\.\"([^\"]+)\"\s*=\s*{([^}]+)}'
        
        matches = re.findall(pattern, self.config_text, re.MULTILINE | re.DOTALL)
        
        for mount_point, config_block in matches:
            fs_config = {}
            
            # Extract device (UUID or path)
            device_match = re.search(r'device\s*=\s*\"([^\"]+)\"', config_block)
            if device_match:
                fs_config['device'] = device_match.group(1)
            
            # Extract filesystem type
            fstype_match = re.search(r'fsType\s*=\s*\"([^\"]+)\"', config_block)
            if fstype_match:
                fs_config['fsType'] = fstype_match.group(1)
            
            # Extract options
            options_match = re.search(r'options\s*=\s*\[([^\]]+)\]', config_block)
            if options_match:
                options_str = options_match.group(1)
                # Parse quoted strings in the list
                fs_config['options'] = re.findall(r'\"([^\"]+)\"', options_str)
            
            filesystems[mount_point] = fs_config
        
        return filesystems
    
    def parse_boot_config(self) -> Dict:
        """Parse boot configuration"""
        boot_config = {}
        
        # Boot loader configuration
        if 'boot.loader.systemd-boot' in self.config_text:
            boot_config['loader'] = 'systemd-boot'
        elif 'boot.loader.grub' in self.config_text:
            boot_config['loader'] = 'grub'
        
        # UEFI support
        if 'boot.loader.efi.canTouchEfiVariables' in self.config_text:
            boot_config['uefi'] = True
        
        # Extract kernel modules
        initrd_modules = re.search(
            r'boot\.initrd\.availableKernelModules\s*=\s*\[([^\]]+)\]',
            self.config_text
        )
        if initrd_modules:
            modules_str = initrd_modules.group(1)
            boot_config['initrd_modules'] = re.findall(r'\"([^\"]+)\"', modules_str)
        
        kernel_modules = re.search(
            r'boot\.kernelModules\s*=\s*\[([^\]]+)\]',
            self.config_text
        )
        if kernel_modules:
            modules_str = kernel_modules.group(1)
            boot_config['kernel_modules'] = re.findall(r'\"([^\"]+)\"', modules_str)
        
        return boot_config
    
    def parse_hardware_modules(self) -> List[str]:
        """Parse nixos-hardware module imports"""
        modules = []
        
        # Find imports section
        imports_match = re.search(
            r'imports\s*=\s*\[(.*?)\];',
            self.config_text,
            re.MULTILINE | re.DOTALL
        )
        
        if imports_match:
            imports_block = imports_match.group(1)
            
            # Find nixos-hardware modules
            hw_modules = re.findall(
                r'inputs\.nixos-hardware\.nixosModules\.([a-zA-Z0-9\-_]+)',
                imports_block
            )
            modules.extend(hw_modules)
        
        return modules
    
    def detect_partition_scheme(self) -> Dict:
        """Detect the partitioning scheme from filesystems"""
        scheme = {
            'type': 'unknown',
            'partitions': [],
            'disk_size_gb': 0
        }
        
        has_boot = False
        has_root = False
        
        # Analyze mount points
        for mount_point, config in self.filesystems.items():
            partition = {
                'mount': mount_point,
                'fstype': config.get('fsType', 'ext4'),
                'size_mb': 0,
                'type': 'primary'
            }
            
            if mount_point == '/':
                has_root = True
                partition['size_mb'] = 'remaining'  # Use remaining space
                partition['label'] = 'nixos'
            elif mount_point == '/boot':
                has_boot = True
                partition['size_mb'] = 512
                partition['label'] = 'boot'
                if config.get('fsType') == 'vfat':
                    partition['type'] = 'EFI System'
            elif mount_point.startswith('/mnt/'):
                # Additional data partition
                partition['size_mb'] = 'remaining'
                partition['label'] = mount_point.split('/')[-1]
            
            scheme['partitions'].append(partition)
        
        # Determine scheme type
        if has_boot and has_root:
            if any(p.get('type') == 'EFI System' for p in scheme['partitions']):
                scheme['type'] = 'uefi'
            else:
                scheme['type'] = 'bios'
        
        # Sort partitions by mount point
        scheme['partitions'].sort(key=lambda x: (
            x['mount'] == '/',  # Root last
            x['mount']
        ))
        
        return scheme
    
    def parse(self) -> Dict:
        """Parse the entire hardware configuration"""
        if not self.load_config():
            return {}
        
        self.filesystems = self.parse_filesystems()
        self.boot_config = self.parse_boot_config()
        self.hardware_modules = self.parse_hardware_modules()
        
        partition_scheme = self.detect_partition_scheme()
        
        return {
            'filesystems': self.filesystems,
            'boot': self.boot_config,
            'hardware_modules': self.hardware_modules,
            'partition_scheme': partition_scheme,
            'source_file': str(self.config_path)
        }


def find_hardware_config(hostname: str) -> Optional[str]:
    """Find the hardware config file for a given hostname"""
    possible_paths = [
        f"hosts/{hostname}/nixos/hardware-configuration.nix",
        f"hosts/{hostname}/hardware-configuration.nix",
        f"hosts/{hostname}/hardware.nix"
    ]
    
    for path in possible_paths:
        if os.path.exists(path):
            return path
    
    return None


def main():
    """Main entry point"""
    if len(sys.argv) != 2:
        print("Usage: parse-hardware-config.py <hostname>")
        print("Example: parse-hardware-config.py p620")
        sys.exit(1)
    
    hostname = sys.argv[1]
    
    # Change to config directory if running from elsewhere
    script_dir = Path(__file__).parent
    config_dir = script_dir.parent.parent
    if config_dir.exists():
        os.chdir(config_dir)
    
    # Find hardware config
    hw_config_path = find_hardware_config(hostname)
    if not hw_config_path:
        print(f"Error: No hardware configuration found for '{hostname}'")
        print("Available hosts:")
        hosts_dir = Path("hosts")
        if hosts_dir.exists():
            for host_dir in hosts_dir.iterdir():
                if host_dir.is_dir():
                    print(f"  - {host_dir.name}")
        sys.exit(1)
    
    # Parse configuration
    parser = HardwareConfigParser(hw_config_path)
    result = parser.parse()
    
    if not result:
        print("Failed to parse hardware configuration")
        sys.exit(1)
    
    # Output as JSON
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()