Then you can build the image and associated metadata.

# nix build .#nixosConfigurations.container.config.system.build.squashfs --print-out-paths

/nix/store/24djf2qlpkyh29va8z6pxrqp8x5z6xyv-nixos-lxc-image-x86_64-linux.img

# nix build .#nixosConfigurations.container.config.system.build.metadata --print-out-paths

/nix/store/2snjw9y8brfh5gia44jv6bhdhmmdydva-tarball

# nix build .#nixosConfigurations.vm.config.system.build.qemuImage --print-out-paths

/nix/store/znk28bp34bycb3h5k0byb61bwda23q5l-nixos-disk-image

# nix build .#nixosConfigurations.vm.config.system.build.metadata --print-out-paths

/nix/store/2snjw9y8brfh5gia44jv6bhdhmmdydva-tarball
Finally, the image can be imported into an Incus storage pool and used to launch instances.

# incus image import --alias nixos/custom/container /nix/store/2snjw9y8brfh5gia44jv6bhdhmmdydva-tarball/tarball/nixos-system-x86_64-linux.tar.xz /nix/store/24djf2qlpkyh29va8z6pxrqp8x5z6xyv-nixos-lxc-image-x86_64-linux.img

Image imported with fingerprint: 9d0d6f3df0cccec4da7ce4f69952bd389b6dd655fd9070e498f591aaffbb2cda

# incus image list nixos/custom/container

+------------------------+--------------+--------+--------------------------------------------------+--------------+-----------+-----------+----------------------+
| ALIAS | FINGERPRINT | PUBLIC | DESCRIPTION | ARCHITECTURE | TYPE | SIZE | UPLOAD DATE |
+------------------------+--------------+--------+--------------------------------------------------+--------------+-----------+-----------+----------------------+
| nixos/custom/container | 9d0d6f3df0cc | no | NixOS Uakari 24.05.20240513.a39a12a x86_64-linux | x86_64 | CONTAINER | 170.31MiB | 2024/05/21 09:21 EDT |
+------------------------+--------------+--------+--------------------------------------------------+--------------+-----------+-----------+----------------------+

# incus launch nixos/custom/container -c security.nesting=true

Launching the instance
Instance name is: square-heron

# incus shell square-heron

[root@nixos:~]# which vim
/run/current-system/sw/bin/vim
