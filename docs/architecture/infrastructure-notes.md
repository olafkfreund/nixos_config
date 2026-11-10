# Infrastructure notes

Things the code no longer shows, so they are easy to get wrong. Moved out of
`AGENTS.md` (Issue #2831); the Hyprland and desktop items are also loaded as a
path-scoped rule in `.claude/rules/desktop.md`.

- **Declared Hyprland keys live in `hosts/common/nixos/omarchy-keys.nix`**, not
  `bindings.lua`; the repo wins on a declared chord. See `docs/architecture/desktop.md`, Keys.
- **No binary cache of our own.** There is no nix-serve/harmonia anywhere in the repo;
  nothing listens on p620:5000. `modules/nix/nix.nix` substitutes from cache.nixos.org and
  nix-community.cachix.org; `flake.nix` adds cuda-maintainers and devenv as flake-level
  `extra-substituters`. Tailscale mesh is used for remote SSH access, not caching.
- **Monitoring was removed** (Prometheus/Grafana/Loki/Alertmanager). Use `journalctl`
  and `systemctl status`.
- **One Wayland session: Nixarchy (Omarchy on Hyprland), plus GNOME.** All three
  hosts offer exactly `omarchy-wayland-session` and `gnome-session`. niri, labwc,
  mango, Noctalia and DankMaterialShell are all gone, and so are their flake
  inputs — anything in the docs or a comment describing `dms-shell.nix`,
  "Niri (DMS)", "Hyprland (DMS)" or `${DESK_SHELL:-noctalia}` is describing a
  tree that no longer exists.
- **`programs.hyprland` is enabled by the nixarchy module, not by us** (#1562).
  It is what supplies the portal, uwsm and the wayland-session basics, so it
  cannot be turned off — but it also registers its own Hyprland login entry.
  `hosts/common/nixos/omarchy-sole-hyprland.nix` forces the module off and
  restates the parts Nixarchy needs, so only Omarchy's session is offered. Read
  that file before touching anything Hyprland-adjacent: there is no option to
  exclude one session, and the two obvious workarounds both fail (a filtered
  `mkForce` on `sessionPackages` reads the value it defines; a session-less
  repackage is rejected by the option's type, which demands
  `providedSessions != [ ]`).
- **The Omarchy theme is the source of truth for colours** (#1562).
  `omarchy theme set X` retints Omarchy's own 24 files at once and a
  `theme-set.d` hook writes X into `nixarchy-theme.nix` at the flake root;
  `modules/desktop/stylix-theme.nix` maps that theme's `colors.toml` onto base16
  and feeds Stylix. Everything Omarchy cannot reach at runtime — Plymouth, GRUB,
  the console, fonts, the remaining home-manager targets — follows **at the next
  rebuild**, not instantly. GTK, Qt colours and icons follow live through the
  theme engine; Stylix's HM gtk/gnome/kde targets are off so they do not
  overwrite it (#2370). Two consequences: switching a theme leaves the tree
  dirty and `nhs` refuses a dirty tree (same as `nixarchy-apply` with
  `apps.nix`), and p510 follows the same palette because `inputs.nixarchy` is
  flake-wide. Reach the package through `inputs.nixarchy`, never
  `config.programs.nixarchy.package` — nixarchy consumes Stylix, so that closes
  the module fixpoint and evaluation dies with infinite recursion.
- **p510 runs the Omarchy session for real** (#1585, superseding the
  arrangement #1562 left behind). It got a monitor, so the three settings that
  held Omarchy at arm's length were inverted: `displayManager = true` (Omarchy's
  SDDM; GDM is gone), `defaultSession = "omarchy"` and `host.class =
  "workstation"`. Two divergences from p620/razer remain, both deliberate:
  `preinstalls = false` (4 GiB of desktop software, `cef-binary` alone 1.9 GiB;
  `/` would go 50.5 → 57.6 GiB) and **autologin stays on** — Sunshine is a
  systemd *user* service that only exists inside a live graphical session, so on
  a host that reboots unattended the alternative is a greeter nobody is there to
  answer. razer keeps autologin off because PRIME-sync Optimus misbehaves with a
  greeter respawn; p510 is pure NVIDIA without PRIME.
  `gnome-remote-desktop` can still serve GNOME over RDP but cannot serve
  Hyprland — that is what Sunshine replaced.
- **Sunshine** (`modules/desktop/sunshine.nix`, `features.sunshine`, p510 only)
  is the standing exception to the DynamicUser/ProtectHome rule in `AGENTS.md`
  (Non-negotiable 2): it needs the session's Wayland socket, GPU nodes and
  input devices. Four traps, in the order you hit them: it starts only with a
  graphical session; a DPMS-off output streams solid black with a clean log
  (`wakeDisplay = true`, and the dispatcher is Lua —
  `hl.dsp.dpms({ action = "enable" })`); `webOrigins` must include the port or
  the web UI refuses every POST with a CSRF error; and setting *any* option
  puts the config in the Nix store, making the web UI's Configuration tab
  read-only. See `docs/applications/sunshine.md`.
- **Self-hosted GitHub Actions runners for nixarchy's KVM/ISO checks live on
  p620 only** — `modules/services/nixarchy-runner.nix`, enabled through
  `services.nixarchy-runner` in `hosts/p620/configuration.nix`. Four runner
  units (`github-runner-nixarchy`, `-nixarchy-2` … `-nixarchy-4`) with the
  labels `nixos`/`kvm`/`big`. p510 ran them too until #1738 removed them.
  **They are targeted, not idle**: nixarchy's `nightly.yml` is
  `runs-on: [self-hosted, nixos, kvm, big]`, and `install-check.yml` picks per
  run — a `gate` job on `ubuntu-latest` decides whether the change can affect
  an install and emits the self-hosted label set only when it can.
  p620's `buildDir` is `/var/lib/nix-build`, its own 480 GB SSD (#2182). The
  module sets both `nix.settings.build-dir` and the nix-daemon `TMPDIR`,
  because `build-dir` supersedes `TMPDIR` and setting only the latter goes
  quietly inert. p510 keeps the same two settings in its host config, pointed
  at `/home/nix-build`: never `/mnt/img_pool`, an SMR ST1000LM035 at
  ~9.5 MB/s, where a 16 GB VM install hangs rather than failing cleanly.
- **An NVIDIA driver version bump cannot be applied with `switch`** — the new
  userspace meets the old in-memory module, three `nvidia-*` units fail and the
  activation rolls back. `nhs` detects this and falls back to `boot` mode; the
  reboot is still yours.
- DEX5550 is offline; Samsung and HP are decommissioned.
- MicroVMs are per-host files (`hosts/p510/microvm.nix`, with the guests under
  `hosts/p510/nixos/microvm/`), not a shared module.
