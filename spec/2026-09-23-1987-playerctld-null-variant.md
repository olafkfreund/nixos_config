---
status: approved
issue: 1987
intent: intent/2026-09-23-1987-playerctld-null-variant.md
---

# Spec: Stop playerctld segfaulting on a body-less D-Bus error

## Design

Patch playerctl 2.4.1 locally with one small C patch, applied through the
existing global overlay for upstream bugs.

**Files**

- `overlays/playerctl-null-variant.patch` (new) — a unified diff against
  `playerctl/playerctl-daemon.c`, beside the repo's other overlay patch
  (`overlays/39-angle-patchdir-fixed.patch`).
- `overlays/upstream-fixes.nix` — add, with a comment naming #1987 and the
  drop condition:

  ```nix
  playerctl = prev.playerctl.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [ ./playerctl-null-variant.patch ];
  });
  ```

**The patch — the two proven crash sites only**

1. `proxy_method_call_async_callback`, `G_DBUS_MESSAGE_TYPE_ERROR` branch:
   use the error text only when `body != NULL`, it has at least one child, and
   child 0 is a string (`G_VARIANT_TYPE_STRING`). Otherwise fall back to the
   existing `"Failed to call method"` reply. This also corrects the child index:
   a D-Bus error body's first argument is its message, so child 0, not child 1.
   The daemon then forwards the player's error to the caller instead of
   crashing.
2. `context_emit_active_player_changed`: build and emit each
   `PropertiesChanged` tuple only when its cached properties
   (`player_properties` / `root_properties`) are non-NULL; otherwise skip that
   one signal with a `g_debug`. `ActivePlayerChangeBegin`/`End` are still
   emitted, so clients still learn which player is active.

**Why a global overlay.** The daemon and the `playerctl` CLI ship in one
package. `modules/system-utils/system_util.nix` puts `playerctl` into
`systemPackages`, and `services.playerctld` (nixpkgs module, `package` defaults
to `pkgs.playerctl`) installs its own copy too. Patching `pkgs.playerctl` in the
overlay (wired for every host via `flake.nix` → `overlays/default.nix`) gives
p620 and razer the fix with no per-host code, and keeps one playerctl on PATH.

The `Restart=on-failure` already committed on main for p620 (3867fc369) stays.
It is extended to razer as a safety net: the same line in
`hosts/razer/configuration.nix`.

## Alternatives rejected

- **Per-host `services.playerctld.package = patched` in p620 and razer
  configs** — duplicates the override in two files and leaves the unpatched
  `playerctl` from `system_util.nix` in `systemPackages` too. That gives two
  different playerctl builds on PATH, which collide on `bin/playerctl`.
- **Build playerctl from upstream master** — master has the same bug (daemon
  file untouched since 2021-01), so it fixes nothing.
- **Change cliamp or omarchy-shell** — ruled out by the intent. Also only
  treats the trigger: any other player sending a body-less error would crash it
  again.
- **Only `Restart=on-failure` / a restart limit tweak** — the crash recurs
  within a second of every start, so restarting cannot keep it up.
- **Disable playerctld** — breaks the bar's media widget and media keys.
- **Send the patch upstream** — declined in the intent (local only).

## Risks

- **Every host that uses playerctl rebuilds it locally** (p620, razer, p510 and
  any other host importing `system_util.nix`), because it leaves the binary
  cache. It is a small meson/C build; the cost is minor.
- **The patch stops applying** when nixpkgs bumps playerctl. The build then
  fails loudly at the patch phase rather than silently; the overlay comment
  says to drop or rebase it then.
- **Behaviour change in fix 2**: a player whose properties could not be fetched
  no longer triggers a `PropertiesChanged` at the moment it becomes active. The
  alternative today is a segfault, and property updates still arrive through the
  normal signal path. Low risk.
- **razer is remote**: its runtime check needs a deploy over SSH and a player
  session there. If razer is offline, it is verified by build only until it
  comes back; that is reported, not assumed.

## Verification

1. **Build:** `nix build .#nixosConfigurations.{p620,razer}.config.services.playerctld.package`
   succeeds, and both evaluate to the same patched store path, not
   `jlrc3mbz…-playerctl-2.4.1`.
2. **The patch is in the binary:** the build log shows the patch applied;
   `strings` on the new `playerctld` still shows `Failed to call method`.
3. **Both hosts evaluate:** `nix eval` of each host's
   `systemd.user.services.playerctld.serviceConfig` shows the patched
   `ExecStart` and `Restart = "on-failure"`.
4. **p620 runtime, the original trigger:** after `nixarchy-apply`, start cliamp
   and Chrome playing, restart `playerctld` and omarchy-shell, then wait 60s.
   `playerctld` stays `active`, `coredumpctl list playerctld` shows no new
   entries, and `busctl --user get-property org.mpris.MediaPlayer2.playerctld …
   PlaybackStatus` answers.
5. **Error path, directly:** `busctl --user get-property
   org.mpris.MediaPlayer2.playerctld /org/mpris/MediaPlayer2
   org.mpris.MediaPlayer2.Player Shuffle` with cliamp active returns a D-Bus
   error to the caller, and the daemon is still running afterwards.
6. **razer:** deploy through the repo's usual remote path, then run
   `systemctl --user is-active playerctld` and `coredumpctl list playerctld`
   over SSH (no new cores after the deploy).
