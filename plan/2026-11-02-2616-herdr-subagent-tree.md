---
status: approved
issue: 2616
spec: spec/2026-11-02-2616-herdr-subagent-tree.md
---

# Plan: subagents as a tree in herdr's sidebar, and no lingering agents

This plan covers Phase A. Phase B (the shim spike, then a spec addendum)
follows only after Phase A is live.

## Decisions carried from the approved spec

- **Reaper.** A systemd user service and a timer every 2 minutes, that act
  only on `/run/user/$UID/tmux-$UID/claude-swarm-<pid>` sockets.
  - **Orphan:** the lead `<pid>` is dead → `kill-server` and remove the
    socket.
  - **Finished teammate:** last `TeammateIdle` is ≥ `idleMinutes` (10) old
    with no activity since → `kill-pane`; kill the server when it has no
    panes left.
  - `dryRun` defaults to true for the first deploy; it logs and never kills.
  - It logs to `journalctl --user -t claude-swarm-reaper`.
- **Hooks.** `TeammateIdle` records `{socket, pane, ts}`. `UserPromptSubmit`
  and `PreToolUse` clear the record. All three act only when `TMUX` contains
  `/claude-swarm-`, and always exit 0.
- **Integrations.** Update herdr's `claude` and `codex` integrations, per
  host, when they are outdated. Also install `antigravity-cli`, which is
  available and missing; its script exits 0 outside herdr, so the synced
  `~/.gemini` is safe on p510.
- **Codex count.** Managed `SubagentStart`/`SubagentStop` hooks drive the
  existing counter with source `codex-subagents`, so a Codex parent row
  shows `agents=N`.
- p620 and razer only.

## Facts used

- The counter script is `subagentScript` in
  `modules/programs/claude-code-managed.nix` (~line 585). It keys on
  `HERDR_PANE_ID` and reports `--source claude-subagents --token agents=N`.
- The sidebar renders `$agents` via `[ui.sidebar.agents.rows_by_agent]` in
  `home/development/herdr.nix`.
- herdr's Codex integration script checks `HERDR_ENV=1`, so Codex hooks get
  herdr's env.
- `herdr integration install <target>` targets include `claude`, `codex` and
  `antigravity-cli`. `herdr integration status` prints
  `<name>: outdated (vX < vY)`, `not installed` or a current state.
- Managed Codex hooks are appended to `environment.etc."codex/requirements.toml".text`
  with `mkAfter`, as in `modules/programs/agent-voice.nix`.
- Unverified: does `TeammateIdle` fire in tmux-pane teammates, and does its
  env carry `TMUX_PANE`? The dry run proves or disproves this live before
  any kill is enabled (step 6).

## Deviations during implementation

- Step 2: the Claude hooks call a small shell guard that `exec`s the reaper
  only when `TMUX` contains `/claude-swarm-`. `PreToolUse` fires on every
  tool call in every session, and a Python start per call would slow them
  all.
- Step 3: Codex gets two wrappers, `/etc/codex/hooks/subagent-inc` and
  `subagent-dec`, instead of one `subagent-count`, because it is not known
  whether managed hook commands take arguments. The counter file name
  includes the source, so the Claude and Codex counts never mix. The Codex
  hooks are folded into the existing `requirements.toml` text; a second
  `mkAfter` definition collided.
- Step 4: the activation puts the user profile bin dirs on PATH, because the
  activation PATH may lack `herdr`.

## Steps

1. **`pkgs/claude-swarm-reaper/`** (new): `claude_swarm_reaper.py`
   (stdlib) and `test_claude_swarm_reaper.py`, packaged like
   `pkgs/agent-say` (python env + makeWrapper, pytest in `checkPhase`),
   with `tmux` on the wrapper PATH. Register it in `pkgs/default.nix`.
   - Subcommands:
     - `hook idle|active` reads the hook payload on stdin and the env
       `TMUX`/`TMUX_PANE`. `idle` writes `$XDG_RUNTIME_DIR/claude-swarm-reaper/<sock>/<pane>.json`
       with `{ts}`; `active` deletes it. It never writes stdout and always
       exits 0.
     - `reap [--dry-run] [--idle-minutes N]` runs the decisions in the
       decision function below and logs each action (or would-action) with
       its reason.
   - The pure decision function takes sockets, lead-alive, panes and
     records, and returns the actions. Tests cover: orphan, idle past the
     window, idle inside it, active after idle, a foreign socket name, a
     pane with no record, and the last pane killed → server killed.

   Check: `pytest`, `ruff check`, `ruff format`.

2. **`modules/programs/claude-swarm-reaper.nix`** (new),
   `features.claudeSwarmReaper`, in the AGENTS.md module shape.
   - Options: `enable`, `idleMinutes` (10), `dryRun` (true),
     `intervalMinutes` (2).
   - Set `systemd.user.services.claude-swarm-reaper` (oneshot,
     `ExecStart = reaper reap ${dryRun flag} --idle-minutes N`) and
     `systemd.user.timers.claude-swarm-reaper` (`OnUnitActiveSec`, `OnBootSec`
     5min). It is a user unit: it must reach the user's tmux sockets, so the
     DynamicUser rule does not apply (the agent-say precedent). Keep
     `NoNewPrivileges`.
   - Add the Claude hooks through
     `modules.programs.claude-code-managed.settings.hooks`: `TeammateIdle` →
     `hook idle`, `UserPromptSubmit` and `PreToolUse` → `hook active`,
     timeout 5.

   Check: eval the units and the managed-settings hooks.

3. **`modules/programs/claude-code-managed.nix`**:
   - `subagentScript` takes an optional second argument `source` (default
     `claude-subagents`).
   - Add `modules.programs.claude-code-managed.subagentMetadata.codex`
     (bool, default false). When it is true, append via `mkAfter` to
     `codex/requirements.toml` `[[hooks.SubagentStart]]` → `… inc
     codex-subagents` and `[[hooks.SubagentStop]]` → `… dec codex-subagents`.
   - Add `environment.etc."codex/hooks/subagent-count"` as a wrapper script,
     because managed commands must live under `/etc/codex/hooks`.

   Check: the rendered `requirements.toml` parses with `tomllib` and still
   has the coder-guard and agent-say entries.

4. **`home/development/herdr.nix`**: a `home.activation` step after
   `writeBoundary`. For each of `claude codex antigravity-cli`, if `herdr
   integration status` shows it `outdated` or `not installed`, run `herdr
   integration install <x>`.
   - Never `exit` in the step.
   - Guard it with `command -v herdr`.
   - On failure, log and continue.

   Check: dry-activation text; the live check comes after deploy.

5. **Hosts**: in `hosts/p620/configuration.nix` and
   `hosts/razer/configuration.nix`, import the reaper module and set
   `features.claudeSwarmReaper.enable = true;` and
   `modules.programs.claude-code-managed.subagentMetadata.codex = true;`.

   Check: `just test-host p620` and `just test-host razer`.

6. **PR, merge after CI, deploy p620 and razer** (bus announced), with
   `dryRun = true`. Then, on p620:
   1. `journalctl --user -t claude-swarm-reaper` lists the 2 live orphan
      servers as `would kill-server (lead dead)`, and nothing else.
   2. Start a coder agent, let it go idle, and confirm a record appears
      under `$XDG_RUNTIME_DIR/claude-swarm-reaper/`. This proves
      `TeammateIdle` fires with `TMUX_PANE`. If it doesn't fire, record the
      deviation here and keep only orphan reaping.
   3. `herdr integration status` reports claude, codex and antigravity-cli
      as current.
   4. A Codex turn that spawns a subagent shows `agents=1` on its row.

   Report the dry-run log to the user.

7. **Enable killing (after the user approves the dry-run log):** set
   `dryRun = false` in both hosts, then PR, merge and deploy. Verify that
   the orphan servers are gone, the user's tmux is untouched, and an idle
   coder agent disappears after 10 minutes.

## Step 6 results (2026-11-02, p620 and razer)

- Both hosts run main `a90ffe2f6`, with no failed units. The reaper timer
  runs every 2 minutes.
- The dry run on p620 found 19 swarm sockets and 15 actions, all
  `would kill-server … (lead dead)`. There were no pane kills, and the 4
  live-lead sockets were left alone.
- `herdr integration status` reports claude v11, codex v10 and
  antigravity-cli v4 current on both hosts.
- **`TeammateIdle` proven:** a running teammate (`claude-swarm-46670`, pane
  `%4`) finished a turn at 17:18:46. A record appeared in the same second,
  so already-running teammates pick up the hook.
- Limitation: panes with no turn since the deploy have no record and are
  left until their lead exits, which is safe by design.
- The user approved step 7 (dry run off) after this log.

## Tests

```bash
nix shell nixpkgs#python3Packages.pytest -c pytest pkgs/claude-swarm-reaper -q
just test-host p620
just test-host razer
```

Plus the live checks in steps 6 and 7.

## Rollback

`features.claudeSwarmReaper.enable = false` and
`subagentMetadata.codex = false`, then rebuild. herdr integration updates
are herdr's own files; `herdr integration uninstall <x>` reverts them.
