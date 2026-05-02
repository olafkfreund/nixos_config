_: {
  # System-level Stylix configuration is fully shared via
  # modules/desktop/stylix-theme.nix. Wallpaper now lives in baseTheme
  # (hosts/common/shared-variables.nix). This file remains as the
  # per-host attach point for any future host-specific theming overrides.
  imports = [ ../../../modules/desktop/stylix-theme.nix ];
}
