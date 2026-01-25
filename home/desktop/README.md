# 🖥️✨ Desktop Environment Configuration

This directory contains declarative, modular configurations for desktop environments, window managers, and related utilities managed through Home Manager. All modules follow the NixOS and Home Manager best practices for reproducibility and maintainability.

## 🧩 Components

- `ags/` — 🦄 AGS (Aylur's GTK Shell) configuration
- `com.nix` — 🛠️ Common desktop utilities and settings
- `default.nix` — 📦 Main entry point importing all desktop modules
- `default-servers.nix` — 🖧 Server-specific desktop configurations
- `dbus.nix` — 🚌 D-Bus session configuration
- `dunst/` — 🔔 Notification daemon configuration
- `evince/` — 📄 Document viewer configuration
- `file-associations.nix` — 📂 Default application associations
- `flameshot/` — 🔥 Screenshot tool configuration
- `gaming/` — 🎮 Gaming-related desktop utilities
- `git-sync/` — 🔄 Git synchronization utilities
- `kdeconnect/` — 📱 KDE Connect for device integration
- `kooha/` — 🎥 Screen recording tool configuration
- `lanmouse/` — 🖱️ LAN mouse sharing configuration
- `mail/` — ✉️ Mail client configurations
- `neofetch/` — 🖼️ System information tool configuration
- `obs/` — 📹 Open Broadcaster Software configuration
- `plasma/` — 💠 KDE Plasma desktop environment configuration
- `remotedesktop/` — 🌐 Remote desktop utilities
- `slack/` — 💬 Slack desktop client configuration
- `sound/` — 🔊 Audio configuration utilities
- `terminals/` — 🖥️ Terminal emulator configurations
- `theme/` — 🎨 Desktop theme configurations
- `thunderbird/` — 🦅 Email client configuration
- `waypipe/` — 🛤️ Remote application forwarding
- `zathura/` — 📚 Document viewer configuration

## 🚀 Usage

These modules are imported by the main desktop configuration file (`default.nix`) and then included in the user's Home Manager configuration. Each component typically provides:

- 📦 Package installation (using flakes and overlays where appropriate)
- ⚙️ Configuration files (declarative, reproducible)
- ⌨️ Keybindings (for window managers)
- 🎨 Theme integration

### 📝 Best Practices

- All modules use 2-space indentation and follow the Nixpkgs and Home Manager contribution guidelines.
- Options are declared with types, descriptions, and example values.
- Use camelCase for variables and descriptive names for clarity.
- Prefer overlays and exact attribute paths for package references.
- Document all custom options and provide usage examples in module files.

---

For more details, see the main repository [README.md](../README.md) and individual module documentation.

