_: {
  # System-level Stylix configuration is fully shared via
  # modules/desktop/stylix-theme.nix. The GNOME target is now gated by
  # host.class in that module (headless-rdp → false), so no override needed.
  imports = [ ../../../modules/desktop/stylix-theme.nix ];
}
