{ lib, ... }: {
  # System-level Stylix configuration is fully shared via
  # modules/desktop/stylix-theme.nix. p510 is a headless server so the
  # GNOME target is overridden back to false. (Phase 3 will replace this
  # mkForce with a `host.class = "headless-rdp"` gate.)
  imports = [ ../../../modules/desktop/stylix-theme.nix ];

  # Headless server — no GNOME session to theme.
  stylix.targets.gnome.enable = lib.mkForce false;
}
