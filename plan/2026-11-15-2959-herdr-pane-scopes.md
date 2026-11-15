---
status: approved
issue: 2959
spec: spec/2026-11-15-2959-herdr-pane-scopes.md
---

# Plan: one systemd scope per herdr pane

Decisions (spec): a `herdr-pane-shell` wrapper in `home/development/herdr.nix`. With a user bus it runs
`systemd-run --user --scope --quiet --collect --unit=herdr-pane-$$ -- bash "$@"`, otherwise plain bash. It is set as
`[terminal] default_shell`. No memory limits.

## Steps

1. `home/development/herdr.nix`: add `paneShell` in the `let` block and the `[terminal]` section in `config.toml`.
   Verify: build the generated `config.toml`, run `HERDR_CONFIG_PATH=<file> herdr config check` (`config: ok`), and
   run the wrapper with `-c 'cat /proc/self/cgroup'` (expect `herdr-pane-<pid>.scope`).
2. `docs/architecture/infrastructure-notes.md`: one bullet on the per-pane scopes and why.
3. Lead: deploy p620 and razer, open a new herdr pane, confirm its shell's cgroup.

## Tests

As in the steps; CI green; `@codex review`.

## Rollback

Revert the squash commit and redeploy.
