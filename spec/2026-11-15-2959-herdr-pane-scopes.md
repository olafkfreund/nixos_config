---
status: approved
issue: 2959
intent: intent/2026-11-15-2959-herdr-pane-scopes.md
---

# Spec: one systemd scope per herdr pane

## Design

herdr 0.9.5 has `[terminal] default_shell`, "Executable used for new interactive panes" (from the binary's default
config). `home/development/herdr.nix` sets it to a `herdr-pane-shell` wrapper:

- with a user bus: `exec systemd-run --user --scope --quiet --collect --unit=herdr-pane-$$ -- bash "$@"`. The
  `--scope` mode runs the command in place, so the PID herdr spawned is the shell;
- without one: `exec bash "$@"`.

The terminal scope then holds only the herdr server and client, which are small, so oomd's largest-cgroup choice
lands on the pane that grew.

## Alternatives rejected

- `ManagedOOMPreference=avoid` on the server: the server runs in the launching terminal's scope, so the setting
  cannot be targeted without moving the server; per-pane scopes already make the server's cgroup small.
- `MemoryMax=` per pane: a limit the owner did not ask for, and it would kill legitimate large builds.

## Risks

- A pane started before the deploy keeps the old cgroup until it is reopened.
- If `systemd-run` fails after the bus check, the pane fails to start. The fix is visible at once; rollback is a
  revert.

## Verification

- `herdr config check` on the generated `config.toml` prints `config: ok`.
- The wrapper run with `-c 'cat /proc/self/cgroup'` lands in `herdr-pane-<pid>.scope`.
- After the deploy, a new herdr pane's shell is in its own `herdr-pane-*.scope`.
