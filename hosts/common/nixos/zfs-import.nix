# Silence nixpkgs' boot.zfs.forceImportRoot deprecation notice.
#
# None of these machines use ZFS. p510, p620 and razer are ext4 throughout
# (plus vfat for the ESP, and nfs/tmpfs where they apply), and
# `boot.zfs.enabled` evaluates false on all three. The warning fires anyway:
# it is emitted whenever the option sits at its default, not when a pool is
# actually imported, so it appears on every evaluation of every host and says
# nothing about this configuration.
#
# What the option does, since silencing a data-loss warning deserves knowing:
# forceImportRoot makes the initrd import the root pool with `zpool import -f`,
# overriding ZFS's own guard against importing a pool another system may still
# have open. That guard exists to stop two machines writing the same pool.
# Upstream is flipping the default to false in 26.11 because forcing it is the
# dangerous choice, and false is what a machine with no pool at all should say.
#
# So this is not "quieting a warning we should heed". It is answering a
# question that does not apply, with the answer that will be the default
# anyway. If a ZFS root is ever added to one of these hosts, revisit this line
# rather than inheriting it.
{
  boot.zfs.forceImportRoot = false;
}
