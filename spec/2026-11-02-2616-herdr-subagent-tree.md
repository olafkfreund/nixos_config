---
status: approved
issue: 2616
intent: intent/2026-11-02-2616-herdr-subagent-tree.md
---

# Spec: subagents as a tree in herdr's sidebar, and no lingering agents

## Research basis

- **Codex** (OpenAI, `codex exec`, read-only): cited findings, verified by
  the session against the repos.
- **Claude Code docs** (via the docs agent): the agent-teams and hooks
  pages.
- **agy:** not obtained. The first run returned only a plan. The second
  failed headless with *"a tool required the "command" permission that
  headless mode cannot prompt for, so it was auto-denied"*. The only
  workaround, `--dangerously-skip-permissions`, is forbidden for reviews.
- **Live on p620, 2026-11-02:**
  - `herdr agent list` shows 4 top-level agents and no subagents.
  - 19 `claude-swarm-*` sockets exist, 2 of them with live servers left by
    finished coder agents.
  - The herdr integrations are outdated (claude v10 < v11, codex v8 < v10).
  - `modules/programs/claude-code-managed.nix` already publishes an
    in-process subagent **count** token (`agents=N`) on the parent's
    sidebar row.

What exists upstream (verified):

| Need | Exists | Limits |
| --- | --- | --- |
| Tree in herdr's native sidebar | [Algorant/herdr-agent-tree](https://github.com/Algorant/herdr-agent-tree) (MIT) | Pi agents only. One `agent.view.set` projection; it can order rows but not create them |
| Claude teammates as herdr panes | [david-lutz/herdr-claude-teams](https://github.com/david-lutz/herdr-claude-teams) (MIT), a `tmux` shim on PATH that maps tmux calls to herdr's socket API | Validated on macOS, herdr 0.6.10 and Claude 2.1.174 only. Panes don't self-close |
| Nested subagents anywhere | zoetrope (installed) | A separate flow graph, not the sidebar |
| Auto-shutdown of finished teammates | None | An idle teammate may still get work (Claude docs) |

## Design

Two phases. Phase A is safe and ships first. Phase B is the tree, and it
ships only after a spike proves the shim on Linux.

### Phase A: no lingering agents, current integrations, counts for Codex

**A1. `claude-swarm` reaper** (`modules/programs/claude-swarm-reaper.nix`,
`features.claudeSwarmReaper`, p620 and razer). It is a systemd **user**
service plus a timer every 2 minutes. The user's own tmux is untouched: it
acts only on sockets named `claude-swarm-<pid>`.

- **Orphans:** the lead Claude process `<pid>` no longer exists → `tmux -S
  <sock> kill-server` and remove the socket. This is always safe, because
  nobody can message these teammates any more.
- **Finished teammates of a live lead:** a teammate pane counts as
  finished when its last `TeammateIdle` (recorded by a hook with its
  `TMUX_PANE`, the socket and a timestamp) is older than `idleMinutes`
  (option, default 10), and nothing has run in that pane since. A newer
  `UserPromptSubmit` or `PreToolUse` from the same pane clears the record.
  Then `tmux -S <sock> kill-pane -t <pane>`, and the server is killed when
  its last pane is gone.
- It never touches a pane without a record, a socket whose name doesn't
  match, or a lead that is still running a turn in that pane.
- It logs one line per action to `journalctl --user -t claude-swarm-reaper`.
- **Option `dryRun`** (default true for the first deploy): it logs what it
  would kill and kills nothing.

**A2. Hooks for A1**, in `claude-code-managed.nix` next to the subagent
counter: `TeammateIdle` writes the idle record. `UserPromptSubmit` and
`PreToolUse` clear it. Each only acts when `TMUX` matches `claude-swarm-`.
They do nothing elsewhere and always exit 0.

**A3. Current herdr integrations.** A home-manager activation step runs
`herdr integration install claude` and `codex` when `herdr integration
status` reports them outdated, per host. `~/.claude/hooks/` is not
Syncthing-synced, so each host does its own.

**A4. Codex subagent count.** Codex has `SubagentStart` and `SubagentStop`
hooks. Wire them as **managed** hooks in `/etc/codex/requirements.toml`,
the same as agent-say, to the existing counter script with
`--source codex-subagents`, so a Codex parent row shows `agents=N` too.
agy has no subagent hooks, so it gets nothing.

### Phase B: the tree (gated)

**B1. Spike, with no repo change until it passes.** Package
herdr-claude-teams pinned, in a scratch herdr session on p620. Run `claude
--teammate-mode tmux` through the shim, spawn two teammates, message them,
shut one down.

Go criteria, all required:

1. The teammates open as herdr panes.
2. Messaging works.
3. Shutdown works.
4. `herdr agent list` shows them.
5. Nothing touches the user's main session.

Fixes needed upstream go to a fork or a patch, as `substituteInPlace` does
in the omateams pattern.

**B2. If go**, a short spec addendum for your approval covers:

- the shim, packaged and put on PATH only for Claude started inside herdr;
- a tree view modelled on herdr-agent-tree, with edges from the shim's
  lead/teammate records;
- how it shares the single `agent.view.set` slot with herdr-radar. radar is
  in maintenance mode, so the tree would own the projection and keep
  radar's project grouping as its order.

A1's reaper then also closes finished teammate **herdr panes** that the
shim created.

**If no-go**, Phase A stands as the result: Claude and Codex counts on the
parent row, and nothing lingering. The tree waits for upstream (herdr
discussion #723).

## Alternatives rejected

- **Kill a teammate on its first `TeammateIdle`:** it fires at the end of
  every turn, and an idle teammate may get more work (Claude docs). It
  would kill teammates the lead still needs.
- **`SubagentStop` as "finished":** it covers Agent-tool subagents, which
  have no pane, and not teammates.
- **Reaping all tmux servers or panes by age:** that could kill the user's
  own tmux.
- **Shim first:** it is unproven on Linux and would put fragile code
  between Claude and every teammate before the safe wins ship.
- **A second `agent.view.set` owner beside radar:** only one projection is
  active; the two would overwrite each other.
- **agy via `--dangerously-skip-permissions`:** forbidden by the repo's
  rules.

## Risks

- **Reaper kills a needed teammate:** the 10-minute idle window, the
  clear-on-activity hooks and the first deploy in `dryRun` make this
  unlikely. Its log shows every decision.
- **`TeammateIdle` might not fire, or might lack `TMUX_PANE`, in tmux-pane
  teammates:** plan step 1 probes this live before any code. If it fails,
  A1 falls back to orphan-only reaping, which still clears the ones seen
  today (their leads are gone).
- **The integration update rewrites hooks in `~/.claude/settings.json`:**
  it is herdr's documented installer, and a diff is taken before and
  after.
- Hosts: p620 and razer only.

## Verification

- `just test-host p620` and `just test-host razer`.
- Unit tests for the reaper's decision function: orphan, idle past the
  window, idle inside the window, activity after idle, foreign socket, no
  record.
- Live on p620:
  1. In `dryRun`, the log lists the two live orphan `claude-swarm` servers
     from today and nothing else.
  2. With `dryRun` off, they are gone and the user's tmux is untouched.
  3. A coder agent left idle for 10 minutes disappears.
- A Codex turn with a subagent shows `agents=1` on its herdr row.
- `herdr integration status` reports claude and codex as current.
- Phase B: the go/no-go checklist above, run and recorded in the plan.

## Addendum B2 (2026-11-02): the tree, after a GO spike

Status: **draft**. It needs the user's approval; Phase A stays approved and
live.

### Spike result: GO

The spike ran in separate headless herdr sessions (`spike-teams`, `spike2`),
which were deleted afterwards. The user's sessions were untouched.

- **Upstream shim** (david-lutz `2c141f0`): Claude 2.1.316 selected the tmux
  backend ("Selected: tmux (running inside tmux session)") and created two
  panes. Then `respawn-pane` failed (unsupported), and Claude closed the
  panes and fell back to in-process teammates. The cause came from Claude's
  `--debug` log and the shim trace.
- **Fork** [rameshbaskaran/herdr-claude-teams](https://github.com/rameshbaskaran/herdr-claude-teams)
  (MIT, `984b08235`), which adds `respawn-pane -k`: all verbs exit 0. `@alpha`
  and `@beta` ran as real herdr panes (`w1:p4`, `w1:p5`), detected by herdr
  as `claude` agents. Both reported to the lead. On shutdown the lead sent
  `kill-pane`, and both panes closed.

All five go criteria passed.

### Review of the fork

The reviewer was Codex (`codex exec`, read-only), verified by the session.
agy was not obtained earlier (headless denial). Three must-fixes, all
confirmed against the code:

1. `kill-pane`, `kill-window` and `kill-session` act on **any** pane, tab
   or workspace in the session, which could include the user's own.
2. `respawn-pane -k` sends Ctrl-C and then the command without waiting.
   If `cat` is still running, it swallows the command and the teammate
   never starts.
3. `select-layout` (Claude calls it; it is in the spike trace) can move
   unrelated panes in the same tab.

### B2 design

1. **Package the fork** as `pkgs/herdr-claude-teams`, pinned at
   `984b08235`, with a local patch `ownership.patch`:
   - **Ownership:** the shim records every pane it creates (by
     `split-window` and `new-window`) in
     `$XDG_RUNTIME_DIR/herdr-claude-teams/<lead pane>.owned`.
     `kill-pane` only closes owned panes; anything else is a logged
     no-op, exit 0. `kill-window` and `kill-session` become logged no-ops.
   - **respawn race:** after the Ctrl-C, poll `pane.process_info` (≤ 2 s)
     until the foreground process is the shell, then type the command.
   - **select-layout:** a no-op.

   The launcher's runtime-written shim is replaced by a store-built
   `libexec/…/shim/tmux` (no write into `~/.cache`). Tests run in
   `checkPhase`, including new ones for the three fixes.

2. **Launch path:** in zsh, `claude` becomes a function that runs
   `herdr-claude-teams` **only when `HERDR_ENV=1`**. Everywhere else it is
   plain `claude`; the launcher itself also falls back. `teammateMode`
   stays `"tmux"` (already the user's setting).

3. **Tree.** Teammates are splits of the lead's tab. herdr-radar already
   renders `$split_mark` for split panes and groups by tab, so the shim
   adds one label: `pane.report_metadata` with token `teammate=<name>` on
   each pane it creates. The Claude row template in `herdr.nix` renders
   `$teammate`, so a child row reads `↳ alpha`. There is no second
   `agent.view.set` owner, so no conflict with radar. If the live check
   shows radar does **not** nest them, fall back to the herdr-agent-tree
   approach (a projection), and that comes back to the user first.

4. **Lingering.** Shutdown already closes the panes (the spike proved it).
   For teammates left idle by a lead that never shuts them down, the Phase
   A reaper is extended: a pane listed in a `.owned` file whose herdr agent
   has been `idle` for `idleMinutes` (from herdr `agent.list`) gets
   `pane.close`. Only owned panes are touched.

### B2 alternatives rejected

- **The upstream shim:** it lacks `respawn-pane`, so teammates fall back to
  in-process.
- **The fork unpatched:** Codex's must-fixes 1-3.
- **Replacing radar with a tree projection now:** two view owners fight,
  and radar's split nesting may already be enough. It is the fallback.
- **Wrapping `claude` globally (PATH):** it would also affect claude
  outside herdr and scripted runs. The zsh function only applies in herdr
  panes.

### B2 risks

- **Claude changes its tmux call shapes again** (it did between 2.1.174
  and 2.1.233). The shim fails closed: Claude falls back to in-process
  teammates, which is today's behaviour. Detected by a smoke test after
  Claude bumps.
- **The respawn race persists despite polling:** the teammate does not
  start, the lead reports it, and the next launch retries.
- **The ownership file is lost** (tmpfs, after a restart): the panes are
  then treated as foreign, so nothing is closed, which is the safe
  direction.

### B2 verification

- `checkPhase` tests: the three fixes, plus the fork's own suite.
- On p620, in the real herdr session:
  1. Start `claude` in a pane and spawn two named teammates.
  2. They appear as panes and in the sidebar nested under the lead, as
     `↳ alpha` and `↳ beta`.
  3. Shutdown closes both.
  4. A `kill-pane` aimed at a foreign pane is refused (unit test, plus a
     check of the trace).
- razer: the same after it is switched.
