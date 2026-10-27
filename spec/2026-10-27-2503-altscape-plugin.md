---
status: draft
issue: 2503
intent: intent/2026-10-27-2503-altscape-plugin.md
---

# Spec: Altscape Alt+Tab switcher on p620 and razer, set up so it sticks

The intent was approved without answers to its three open questions. This
spec takes the defaults below, each marked **(default — override at review)**.

1. **Enabling is automatic, once per host,** with a marker, the same way
   nixarchy enables its `defaultPlugins`. Turn it off in Setup > Plugins and
   it stays off. **(default — override at review)**
2. **Super+Tab on p620 goes back to Omarchy's default** (next workspace) when
   the dead woogy7 block is removed. Altscape takes only Alt+Tab.
   **(default — override at review)**
3. **No bar widget.** Keyboard only, plus Super+Alt+Shift+S for settings. The
   widget can be added at runtime later with no rebuild.
   **(default — override at review)**

## How Hyprland reaches a binding here (measured on p620, 2026-10-27)

Hyprland runs `--config <store>/share/omarchy/config/hypr/hyprland.lua`,
which requires `hypr.{monitors,input,bindings,looknfeel,autostart}` from
`~/.config/hypr`, and `hypr.hyprforge` optionally. `~/.config/hypr/hyprland.lua`
is never loaded. The repo already has a pattern for Nix-owned bindings:
`hosts/common/nixos/omarchy-{ai-mirror,microvm,…}.nix` write
`~/.config/hypr/<name>-binds.lua`, and the user-owned `bindings.lua` loads
each with `pcall(require, "hypr.<name>-binds")`. Both hosts have seven such
lines today. So far each line was added by hand, and that one manual step is
what this spec removes for Altscape.

## Design

### 1. Package: `pkgs/altscape/default.nix`

Modelled on `pkgs/omapop/default.nix`: `stdenvNoCC`, `dontBuild = true`, and
`substituteInPlace --replace-fail` for every change, so a renamed upstream
call site fails the build instead of shipping a quietly broken plugin.

- **Source:** `fetchFromGitHub { owner = "qempexe"; repo = "omarchy-altscape";
  rev = "3f99f8f…"; hash = "sha256-PVtoTZxtE9FhOpNymurlTQXzjB7tGqzu4DDWqecuUvk="; }`
  (full rev in the plan). `version = "1.0.2"`, matching `manifest.json`. A
  `# Bump against: gh api repos/qempexe/omarchy-altscape/commits --jq '.[0].sha'`
  line, as in omapop, and a line in `.claude/commands/check-updates.md`.
- **`hyprctl` baked in:** in `qml/Service.qml`, the three `hyprctl -j` calls in
  the snapshot command become `${hyprland}/bin/hyprctl -j`. `hyprland` is an
  argument, overridden from the host with `config.programs.hyprland.package`
  exactly as omapop does, so it matches the running compositor.
- **The binding helper never edits files.** `bin/altscape-binds` is replaced
  with a short Nix-written script with the same CLI (`sync|remove|status`).
  It edits nothing. It prints the same one-line JSON, with
  `format:"lua"`, `file:"~/.config/hypr/altscape-binds.lua"`, `shortcut:"alt"`,
  `changed:false`, and `active` taken from `hyprctl -j binds`. If the settings
  panel asks for `super` or `off`, `error` reads "Alt+Tab is set by NixOS
  (hosts/common/nixos/omarchy-altscape.nix)", so the UI says why rather than
  failing silently. Upstream's `Service.qml` calls it on start and on a
  shortcut change, which is harmless now.

### 2. Host module: `hosts/common/nixos/omarchy-altscape.nix`

Imported from `hosts/p620/nixos/nixarchy.nix` and
`hosts/razer/nixos/nixarchy.nix`, next to `omarchy-omapop.nix`.

- `programs.nixarchy.plugins."io.github.qempexe.altscape".src =
  pkgs.customPkgs.altscape.override { hyprland = config.programs.hyprland.package; };`
  plus `customPkgs.altscape` registered in `pkgs/default.nix`.
- **`~/.config/hypr/altscape-binds.lua`** (`home.file`, read-only, Nix-owned),
  generated from the same block upstream's helper writes for `alt`, without
  the manifest guard (Nix guarantees the plugin is present):

  ```lua
  hl.unbind("ALT + TAB")
  hl.unbind("ALT + SHIFT + TAB")
  o.bind("ALT + TAB", "Altscape: next window", "omarchy-shell shell summon io.github.qempexe.altscape next")
  o.bind("ALT + SHIFT + TAB", "Altscape: previous window", "omarchy-shell shell summon io.github.qempexe.altscape prev")
  o.bind("ALT + Alt_L", "Altscape: switch on release", "omarchy-shell shell summon io.github.qempexe.altscape release", { release = true })
  o.bind("ALT + Alt_R", "Altscape: switch on release", "omarchy-shell shell summon io.github.qempexe.altscape release", { release = true })
  o.bind("SUPER + ALT + SHIFT + S", "Altscape settings", "omarchy-shell io.github.qempexe.altscape settings")
  ```

- **The `require` line, ensured at activation.** A `home.activation` step
  (`entryAfter [ "writeBoundary" ]`) appends exactly
  `pcall(require, "hypr.altscape-binds") -- managed by NixOS (#2503)` to the
  end of `~/.config/hypr/bindings.lua` if no line already contains
  `"hypr.altscape-binds"`. It appends only, once. It never rewrites or
  reorders the file, so your edits stay yours. It sits last, so its
  `hl.unbind` wins Tab over anything earlier. If `bindings.lua` doesn't exist
  yet (a fresh machine before nixarchy's seed), it does nothing and the next
  activation adds the line. `pcall` means a generation without
  `altscape-binds.lua` can never break the whole Hyprland config.
- **Enable once, automatically.** An `xdg.configFile` hook at
  `omarchy/hooks/post-boot.d/altscape-enable` runs at each session start and
  copies nixarchy's `default-plugins` hook in miniature. If the marker
  `~/.local/state/nixarchy-local/enabled-once/io.github.qempexe.altscape`
  exists it exits. Otherwise it waits up to 120 s for `omarchy-shell shell
  ping`, runs `omarchy-shell shell rescanPlugins`, then
  `omarchy-plugin-enable io.github.qempexe.altscape`, and writes the marker
  only if that worked. Errors go to `systemd-cat -t altscape-enable`. It
  never edits `shell.json` (the shell owns it). The marker directory is ours,
  not nixarchy's `enabled-once`, so nixarchy's cleanup logic can't touch it.

### 3. p620's dead woogy7 block (one-time, by hand, in the plan)

`~/.config/hypr/bindings.lua` lines 31–107, between
`-- >>> Workspace Switcher (io.github.woogy7.workspaces)` and
`-- <<< Workspace Switcher`, are deleted after a timestamped backup. The
plugin is no longer on disk (`~/.config/omarchy/plugins/io.github.woogy7.workspaces`
is absent), so these binds only call a missing plugin. This is a user file,
so it isn't in the diff. The plan does it as a checked step, removing between
the markers with `sed`, then `hyprctl reload` and `hyprctl configerrors`
empty. razer has no such block.

## Alternatives rejected

- **Let upstream's helper write the block.** It targets the dead
  `hyprland.lua` here (or `bindings.lua` only when `hyprland.lua` is missing),
  rewrites it on every shell start, and puts a store path in your file that
  dies at the next GC. That is the opposite of sticking.
- **Patch the helper to write into `bindings.lua`.** Still a runtime writer
  of a user file, still a store path that goes stale, and a second writer
  racing your edits. The Nix-owned `altscape-binds.lua` with one appended
  `require` line has no runtime writer at all.
- **Have Nix own all of `bindings.lua`.** It holds your own binds and seven
  other requires. The intent forbids taking it over.
- **Manual `omarchy plugin enable` (the omapop/ai-mirror precedent).** The
  intent asks for it to stick with no hand steps. The hook is about 20 lines
  copied from nixarchy's own approach.
- **Upstream's `super` / `off` shortcut choice at runtime.** Dropped:
  supporting it would mean a runtime writer again. Changing the key is a
  one-line edit in the host module.

## Risks

- **Two bindings for Alt+Tab** if the woogy7 block stays on p620. Both
  `hl.unbind` before binding, and Altscape's line is last, so Altscape wins
  anyway. Removing the block (step 3) is cleanup, not a requirement.
- **A plugin bump changes `Service.qml`** so the `hyprctl` substitution
  misses. `--replace-fail` stops the build.
- **Enabling reloads the shell's plugins,** which my notes link to a double
  shell / IPC crash on hot reload. The hook runs once and only at session
  start. The plan restarts the shell cleanly after the first enable on each
  host and checks there is a single bar.
- **First enable on razer happens at its next login,** or when the plan runs
  the hook by hand after deploy.
- **Hosts:** p620 and razer only. p510 imports none of this.

## Verification

- `nix build .#nixosConfigurations.p620.pkgs.customPkgs.altscape` works.
  `result/bin/altscape-binds status` prints valid JSON and edits nothing
  (checked with `stat` on `~/.config/hypr/*` before and after).
- `just test-host p620`, `just test-host razer`.
- After deploy, on each host:
  - `grep -c 'hypr.altscape-binds' ~/.config/hypr/bindings.lua` gives `1`,
    and a second activation still gives `1` (idempotent).
  - `hyprctl configerrors` is empty.
  - `hyprctl repl 'return package.loaded["hypr.altscape-binds"] ~= nil'`
    gives `true`.
  - `hyprctl -j binds` shows exactly one ALT (modmask 8) TAB bind, whose arg
    contains `io.github.qempexe.altscape`.
  - The enable hook's marker exists, and `omarchy plugin list` shows
    `io.github.qempexe.altscape enabled`.
  - `omarchy-shell shell summon io.github.qempexe.altscape next` shows the
    switcher layer (`hyprctl -j layers`).
  - Alt+Tab by hand (yours): it opens, cycles, and switches on release.
- p620: lines 31–107 gone, a backup exists, and Super+Tab does Omarchy's
  next-workspace.
