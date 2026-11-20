---
status: approved
issue: 3144
spec: spec/2026-11-20-3144-plugins-unload.md
coders:
  1: coder  # pkg: state into a singleton, tests kept
  2: coder  # podman: shared PodmanState singleton, per-surface polling
  3: coder  # flatsnap: model into a singleton, menu only
  4: coder  # govee: client into a singleton, hide on dismiss
reviewers:
  - codex   # diff review of each plugin PR
  - agy     # independent diff review
---

# Plan: make pkg, podman, flatsnap and govee safe to unload

## Approved decisions (from the spec)

- **One pattern for all four:** the nixarchy-devenv `DevenvState` pattern,
  as #3139 used for herdr.
  - The object that owns processes that change state becomes a
    `pragma Singleton` file.
  - A `qmldir` lists only that singleton.
  - The menu and the bar become views of it.
  - `keepLoaded` is dropped, the version gets a minor bump, and the wording
    is updated.
- **pkg:** `PkgModel` state, with `_writer`, `_reindexer`, `_check` plus the
  apply chain, and `_applyTerm`.
- **podman:** a single shared `PodmanState`. Polling becomes per-surface
  requests, so the menu closing never stops the bar's polling.
- **flatsnap:** `FlatsnapModel` (menu only).
- **govee:** `GoveeClient`, shared by `Govee.qml` and `GoveeMenu.qml`.
  `dismiss()` hides instead of calling `shell.hide`.
- **Results across an unload:** a result that arrives while a menu is
  unloaded stays in the singleton, and the next open shows it.
- **This repo:**
  - input overrides for the three nixarchy plugins, with removal comments;
  - a new `omagovee` input (`flake = false`);
  - a new `hosts/common/nixos/omarchy-govee.nix` module that sets
    `programs.nixarchy.plugins."olafkfreund.govee".src`, imported by p620
    and razer;
  - the hand-copied govee directory moved aside once before the first
    switch.

## Steps

Steps 1-4 run in parallel, one coder each, in their own clones under
`/home/olafkfreund/.config/<repo>-3144`, on branch
`perf/3144-unload` from the default branch. Each coder runs that repo's
tests and leaves the work uncommitted. The lead reviews, commits, pushes,
opens the PR, runs the Codex and agy reviews, and merges after CI.

1. **olafkfreund/nixarchy-pkg** (`main`).
2. **olafkfreund/nixarchy-podman** (`master`).
3. **olafkfreund/nixarchy-flatsnap** (`main`).
4. **olafkfreund/omagovee** (`main`), in `plugin/`.

   Verify each: `jq -e 'has("keepLoaded")|not' manifest.json`. Each repo's
   own tests pass. Each changed QML file compiles headless against the
   installed omarchy-shell, in the style of nixarchy-herdr's
   `tests/qml-load.sh`.

   Traps:
   - Tests that read source text, such as herdr's `session-actions.cjs`
     (#3139), must be updated, not weakened.
   - A `qmldir` that lists only the singleton hides other types from a
     test's root file. Harnesses may add lines to their temporary copy only.
5. **This repo** (lead), in the worktree
   `/home/olafkfreund/.config/nixos-3144`:
   - the `flake.nix` overrides and the `omagovee` input;
   - `hosts/common/nixos/omarchy-govee.nix`, imported in the p620 and razer
     host configs;
   - `nix flake lock`, then `just test-host p620` and
     `just test-host razer`;
   - the PR, merged after CI.
6. **Deploy** (lead). On p620, move `~/.config/omarchy/plugins/olafkfreund.govee`
   aside, to a backup under `~/.local/state`. Then, with a bus post for
   each host, run `just quick-deploy p620` and
   `just deploy-via-p620 razer`. razer gets the same move-aside first if it
   has a hand copy. Check:
   - the manifests have no `keepLoaded`;
   - no units failed;
   - the govee plugin link points at the store.

## Tests

| Where | Expected |
|---|---|
| each plugin repo | its tests and CI pass; no `keepLoaded` |
| this repo | p620 and razer build |
| p620 live | each menu opens, acts and closes; govee Esc hides |

## Rollback

- Revert this repo's PR. Restore the govee backup directory if the input is
  gone.
- With a bus post for each host, deploy p620 and razer again.
