---
paths:
  - "hosts/common/nixos/omarchy-*.nix"
  - "modules/desktop/**"
  - "hosts/*/nixos/nixarchy.nix"
  - "hosts/*/nixarchy/**"
---

# Desktop notes (Nixarchy / Omarchy / Hyprland)

Full list: `docs/architecture/infrastructure-notes.md`. Read
`docs/architecture/desktop.md` first.

- **Declared Hyprland keys live in `hosts/common/nixos/omarchy-keys.nix`**, not
  `bindings.lua`; the repo wins on a declared chord.
- **One Wayland session: Nixarchy (Omarchy on Hyprland), plus GNOME.** niri,
  labwc, mango, Noctalia and DankMaterialShell are gone, with their flake
  inputs; docs or comments describing them are stale.
- **`programs.hyprland` is enabled by the nixarchy module, not by us** (#1562).
  It cannot be turned off, but it registers its own login entry.
  `hosts/common/nixos/omarchy-sole-hyprland.nix` forces it off and restates
  what Nixarchy needs. Read that file first: a filtered `mkForce` on
  `sessionPackages` reads the value it defines, and a session-less repackage
  fails the option type (`providedSessions != [ ]`).
- **The Omarchy theme is the source of truth for colours** (#1562).
  `omarchy theme set X` writes X into `nixarchy-theme.nix`;
  `modules/desktop/stylix-theme.nix` feeds Stylix from its `colors.toml`.
  Plymouth, GRUB, console, fonts and remaining HM targets follow at the next
  rebuild; GTK, Qt and icons follow live (Stylix's HM gtk/gnome/kde targets are
  off, #2370). A theme switch dirties the tree and `nhs` refuses a dirty tree.
  Reach the package through `inputs.nixarchy`, never
  `config.programs.nixarchy.package` (infinite recursion).
- **p510 runs the Omarchy session for real** (#1585): SDDM, `defaultSession =
  "omarchy"`, `host.class = "workstation"`, `preinstalls = false`, autologin on
  (Sunshine is a systemd user service that needs a live graphical session).
- **Sunshine** (`modules/desktop/sunshine.nix`, p510 only) is the exception to
  the DynamicUser/ProtectHome rule. Traps: starts only with a graphical
  session; DPMS-off streams black (`wakeDisplay = true`, Lua dispatcher
  `hl.dsp.dpms({ action = "enable" })`); `webOrigins` must include the port;
  setting any option makes the web UI Configuration tab read-only. See
  `docs/applications/sunshine.md`.
