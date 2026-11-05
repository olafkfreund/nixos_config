---
status: approved
issue: 2717
intent: intent/2026-11-05-2717-declare-hypr-keys.md
---

# Spec: declare and document Hyprland keys and panel layout

## Design

### Keys

A new module, `hosts/common/nixos/omarchy-keys.nix`, imported by p620 and razer, holds the keys as
data:

- `local.omarchy.keys.shared`: a list of `{ key, description, action }` set in the module, with `lua
  = true` for an action that is a Lua expression.
- `local.omarchy.keys.extra`: the same shape, set per host.
- `local.omarchy.keys.unbind`: chords to free with no replacement, such as Omarchy's HEY keys.
- `local.omarchy.keys.external`: `{ key, description }` for keys bound elsewhere in the repo, so the
  check and docs cover them without binding them twice.
- `local.omarchy.keys.fragments`: the Lua modules to load, plus per-host additions.
- `local.omarchy.keys.workProfile`: `"Profile 4"` on p620, `"Profile 5"` on razer. It feeds the
  Gmail, compose and Google Docs actions.
- `local.omarchy.keys.calendarCommand`: per host, since Calendar is an installed app on p620 and a
  URL window on razer.

The module generates two Home Manager files:

- `~/.config/hypr/repo-keys.lua`: loads the fragments, applies `unbind`, then for each key runs
  `hl.unbind(key)` and `o.bind(key, description, action)`.
- `~/.config/hypr/repo-keys.json`: the declared, external and unbound chords, for the check.

A build assertion normalises each chord (upper case, sorted modifiers) and fails if two entries on a
host share one, across `shared`, `extra` and `external`.

`autostart.lua`, already repo-owned with `force = true` in `omarchy-layouts.nix`, loads `repo-keys`.
The store's `hyprland.lua` loads it after `bindings.lua`, so this works on a new host with no edit
to `bindings.lua`. Only `hypr.hyprforge` and `default.hypr.toggles` run later.

Errors must surface. For `repo-keys` and each fragment, the loader checks `package.searchpath`
first, so a missing file is skipped quietly, then uses `pcall(require, ...)` and on failure calls
`hl.exec_cmd("omarchy-notification-send ...")` with the error. Super+K's stub makes `hl.exec_cmd` a
no-op, so it doesn't notify on each press.

Shared fragments: `hypr.workspace-groups`, `hypr.gog-binds`, `hypr.meet-binds`,
`hypr.ai-mirror-binds`, `hypr.nixi-companion-binds`, `hypr.microvm-binds`,
`hypr.plugin-browser-binds`, `hypr.altscape-binds`, `hypr.agent-voice-binds` and `hypr.flea-binds`.
p620 adds `hypr.meetingai-binds`, so razer doesn't load it even if a stale file exists.

Keys that move in:

| Set | Keys |
| --- | --- |
| Shared | Gmail, New email, Calendar, AI Kit, New Doc, Sheet and Slides, Maps, Photos, Messages, WhatsApp, Exposé, Nixi, voice control, Minimize, Herdr sessions, GitHub Actions (2), GitLab Pipelines (2), Bar settings, Quick actions, nixarchy packages, Dev environments, Distrobox, Podman, OmaFob |
| p620 only | Govee (`extra`) |
| Unbound | SUPER+SHIFT+E, SUPER+SHIFT+ALT+E |

Voice control on SUPER+M and Minimize on SUPER+N are both unconditional, which replaces today's
`o.cmd_present("omarchy-voice")` guard. Both hosts have the command, and a guard would leave the
check and the keymap disagreeing on a host without it. On such a host the key does nothing.

These stay out: Vimarchy's submap and ALT+SPACE (decision 1), and Omgato's keys (decision 3), which
are documented only. Keys already in repo modules stay there and are listed in `external`: MicroVMs,
Plugin Browser, Nixi companion, Meeting AI and the rest.

### Local files at rollout

On p620 and razer, with a backup, remove the migrated binds from `bindings.lua`, so a key later
dropped from the repo doesn't survive there. Load lines stay: they're harmless, since `require`
caches a module, and `omarchy-altscape.nix` would append its own line again anyway. Vimarchy and
comments stay. Remove the `apps.distrobox` and `apps.podman` rows from p620's menu extension, since
a user row overrides a declared one.

### Menu rows

`programs.nixarchy.menu.extraEntries` in the new module declares, with `icon`, `label`,
`description` and `aliases` as they are today:

- `apps.distrobox`: action `nixarchy-plugin nixarchy.distrobox`
- `apps.podman`: action `nixarchy-plugin nixarchy.podman`

They appear at the next login, once the session uses the new Omarchy tree.

### Panel placement

A post-boot hook, `zz-bar-free-once`, sorts after Omarchy's `default-plugins` and `enable-once`. It
handles `nixarchy.microvm`, `nixarchy.distrobox`, `nixarchy.podman`, `nixarchy.devenv` and
`io.github.olafkfreund.nixarchy-plugin-browser`.

The shell has no call that moves a widget from the bar to `plugins[]`: `enablePlugin` puts a widget
on the bar, and `setPluginEnabled false` can't add a `plugins[]` record. So the hook writes the file
itself, with these guards:

1. Skip any id with a marker in `~/.local/state/nixarchy-local/bar-free-once/`.
2. Wait for `omarchy-shell shell ping`, as `enable-once` does, then until `shell.json` has been
   unchanged for 5 seconds.
3. Skip any id whose plugin isn't installed, leaving no marker.
4. Compute the new file with `jq`. Before renaming over `shell.json`, compare its modification time
   with the one read at the start; if it changed, stop and leave this for the next login.
5. After a short wait for the shell's reload, re-read `shell.json`. Write a marker only for an id
   that is in `plugins[]` and not on the bar.

An id that's in neither place gets no marker, so a fresh host retries when the plugin appears. A
failure is logged with `systemd-cat`.

The marker means a later choice in Settings stays (decision 4). On p620 the five are already moved,
so the hook only writes markers at next login. razer moves at its next login.

### Check

`hypr-keys-check`, a `writeShellApplication` package from the module, reads `repo-keys.json` and
fails if:

- a declared or external key is missing from `hyprctl binds`, or its description differs;
- a declared or external key is missing from `omarchy-menu-keybindings --print`;
- a chord in `unbind` is still bound;
- a chord in the normal keymap has more than one bind (ignoring submaps, release and mouse binds);
- with `--docs <file>`, a declared or external chord and its description aren't both in the same row
  of the docs.

`hyprctl` reports Lua binds without their command, so it can't compare actions. Per-host actions are
tested at build time instead: p620's generated file must contain `Profile 4` and no `Profile 5`, and
razer's the reverse.

### Docs

A new "Keys" section in `docs/architecture/desktop.md` lists declared, per-host and plugin-owned
keys, how to change them, and the dormant Hyprforge clash. No nav change is needed. The stale
sentences saying layouts load from `autostart.lua` and that a nixarchy follow-up is pending are
corrected. `AGENTS.md` gets one line pointing at the module.

## Alternatives rejected

- **Home Manager owns `bindings.lua` with `force = true`.** It would also take over the Vimarchy
  block and lines plugins append, such as Omgato's load line, and plugins can't write to a store
  symlink.
- **Append one loader line to `bindings.lua`.** That is Altscape's pattern, but it does nothing when
  the file doesn't exist yet at activation, as on a new host.
- **Keys spread across feature modules with nothing shared.** The check and docs would have nothing
  single to compare against.
- **Move all fragment keys into the one list.** Those modules work and some are generated by
  upstream Home Manager modules, so `external` covers them with less churn.
- **Declare `shell.json` in the repo.** The shell writes it live, and decision 4 lets live changes
  stay.
- **Reuse `enable-once`.** It only calls `omarchy-plugin-enable`, which puts a plugin with a bar
  widget back on the bar.
- **Drop Exposé and AI Kit now.** The intent says no key may lose its bind.

## Risks

- **Repo wins on the same chord.** `repo-keys` unbinds first, so hand-editing a declared key in
  `bindings.lua` has no effect, and a plugin that takes a declared chord is silently overridden.
  Hyprforge, which loads later, would instead add a duplicate, which the check reports. A hand-added
  key on a different chord still works.
- **Writing `shell.json` isn't race-free.** A Settings change in the moment between the
  modification-time check and the rename would be lost. The window is milliseconds, once per host,
  right after startup, and a lost write is visible and repeatable by hand. Without a shell call for
  this move, it can't be closed entirely.
- **Plugin-managed files.** GitHub Actions and GitLab Pipelines call scripts under
  `~/.config/omarchy/plugins`, and those plugins are installed by hand. On a new host their keys do
  nothing until then. Omgato's default SUPER+ALT+L would clash on a fresh Omgato install; the check
  catches that.
- **Actions aren't checked at run time.** A wrong command with the right chord and description
  passes the run-time check. The build test covers only the Chrome profile.
- **Timing.** Keys arrive at the next config load. Menu rows, the hook's panel move and the store's
  `layouts.lua` load all need a login, so razer's check is only meaningful after one.
- **Two keys may do nothing today.** No plugin on p620 or razer was found that handles
  `expose.window-overview`, and `aikit` isn't on `PATH` on either host. They stay declared, as the
  intent requires, with a follow-up issue to fix or remove them.

## Decision at spec approval

The repo wins on a declared chord (user, 2026-11-05). To change a declared key, edit the repo.
Hand-added keys on other chords keep working, and live panel and menu changes stay.

## Verification

- `nix build` of the p620, razer and p510 toplevels; p510's closure doesn't change.
- The assertion fails on a deliberately duplicated chord, including with its modifiers reordered.
- The build test fails with the wrong `workProfile`.
- `luac -p` on the generated `repo-keys.lua`; a broken fragment in a test raises a notification and
  doesn't stop the config load; a missing fragment is skipped quietly.
- After switching and logging in on each host:
  - `hypr-keys-check --docs docs/architecture/desktop.md` passes, and fails after temporarily adding
    a duplicate.
  - `omarchy-menu-keybindings --print` finishes within its normal time.
  - `shell.json` has all five ids in `plugins[]` and none on the bar, and each has a marker.
  - `nixarchy-plugin <id>` followed by `omarchy-shell shell isOpen <id>` returns true for each of
    the five.
  - The generated Omarchy menu file contains `apps.distrobox` and `apps.podman`, with p620's local
    copies gone.
- Turning a plugin back on in Settings survives a rebuild and a login, and the hook doesn't move it
  again.
- A new-host test in a `nixarchy-desktop` microVM, or by moving `bindings.lua` aside: the keys
  appear with no hand edit.
