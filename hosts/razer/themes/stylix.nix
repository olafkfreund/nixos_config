_: {
  # System-level Stylix configuration is shared across hosts via
  # modules/desktop/stylix-theme.nix. Only the per-host wallpaper differs.
  imports = [ ../../../modules/desktop/stylix-theme.nix ];

  host.theme.wallpaper = ./orange-desert.jpg;
}
