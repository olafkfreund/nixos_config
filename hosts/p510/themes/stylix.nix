_: {
  # System-level Stylix configuration is fully shared via
  # modules/desktop/stylix-theme.nix. Its GNOME target is gated on host.class
  # there, and this host is class workstation since it gained a monitor and the
  # Omarchy session, so the target is on and no override is needed. The palette
  # itself follows the Omarchy theme -- ../nixos/nixarchy.nix imports
  # omarchy-stylix-theme.nix, the same hook p620 and razer use.
  imports = [ ../../../modules/desktop/stylix-theme.nix ];
}
