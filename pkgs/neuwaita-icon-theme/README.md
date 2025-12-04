# Neuwaita Icon Theme for NixOS

A Nix package for the [Neuwaita icon theme](https://github.com/RusticBard/Neuwaita) - a different take on the Adwaita theme.

## Installation

### Method 1: Using the flake package directly

You can install the icon theme directly in your NixOS configuration or Home Manager:

```nix
# In configuration.nix or home.nix
environment.systemPackages = [
  # System-wide installation
  inputs.self.packages.x86_64-linux.neuwaita-icon-theme
];

# OR in Home Manager
home.packages = [
  # User installation
  inputs.self.packages.x86_64-linux.neuwaita-icon-theme
];
```

### Method 2: Using the custom packages overlay

Since the package is also available in the custom packages overlay:

```nix
# In configuration.nix or home.nix
environment.systemPackages = [
  pkgs.customPkgs.neuwaita-icon-theme
];
```

### Method 3: Setting as GTK icon theme

To use Neuwaita as your icon theme in GTK applications:

```nix
# In Home Manager configuration
gtk = {
  enable = true;
  iconTheme = {
    name = "Neuwaita";
    package = inputs.self.packages.x86_64-linux.neuwaita-icon-theme;
  };
};
```

### Method 4: Manual installation for testing

Build and install the package for testing:

```bash
# Build the package
nix build .#neuwaita-icon-theme

# Link to your icons directory
ln -sf ./result/share/icons/Neuwaita ~/.local/share/icons/
```

## Features

- Modern, clean icon design based on Adwaita
- Full compatibility with GTK and GNOME applications
- Customization scripts included:
  - `change-color.sh` - Change folder colors
  - `watch-accent.sh` - Watch for accent color changes (requires systemd)

## Customization

The installed package includes customization scripts in the theme directory:

```bash
# Find the installation path
THEME_PATH=$(nix build .#neuwaita-icon-theme --no-link --print-out-paths)/share/icons/Neuwaita

# Run customization scripts
bash $THEME_PATH/change-color.sh
bash $THEME_PATH/watch-accent.sh
```

## Package Information

- **Source**: <https://github.com/RusticBard/Neuwaita>
- **License**: GPL-3.0-or-later
- **Platforms**: Linux
- **Version**: Tracks upstream unstable branch

## Updating the Package

To update to the latest version:

1. Get the latest commit hash from the repository:

   ```bash
   git ls-remote https://github.com/RusticBard/Neuwaita.git HEAD
   ```

2. Update the `rev` in `flake.nix`

3. Get the new hash:

   ```bash
   nix-prefetch-url --unpack "https://github.com/RusticBard/Neuwaita/archive/NEW_COMMIT_HASH.tar.gz"
   nix hash convert --hash-algo sha256 HASH_FROM_ABOVE
   ```

4. Update the `hash` field in `flake.nix`

## Building from Source

```bash
# Build the package
nix build .#neuwaita-icon-theme

# Check the output
ls -la ./result/share/icons/Neuwaita/
```

## Troubleshooting

### Icons not appearing

1. Ensure GTK cache is updated:

   ```bash
   gtk-update-icon-cache -f -t ~/.local/share/icons/Neuwaita
   ```

2. Restart your desktop session or application

3. Check that the theme is properly installed:

   ```bash
   ls ~/.local/share/icons/Neuwaita/index.theme
   ```

### Using with different desktop environments

- **GNOME**: Use GNOME Tweaks to select the icon theme
- **Plasma/KDE**: Use System Settings → Icons
- **XFCE**: Use Appearance Settings → Icons
- **Hyprland/i3/etc**: Configure via GTK settings in Home Manager
