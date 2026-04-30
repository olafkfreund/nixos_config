{ lib, ... }: {
  # System-level Stylix configuration is shared across hosts via
  # modules/desktop/stylix-theme.nix. p510 is a headless server so the
  # GNOME target is overridden back to false.
  imports = [ ../../../modules/desktop/stylix-theme.nix ];

  host.theme.wallpaper = ./orange-desert.jpg;

  # Headless server — no GNOME session to theme.
  stylix.targets.gnome.enable = lib.mkForce false;
}
