# Herdr

A terminal workspace manager for coding agents — a multiplexer like tmux, but
mouse-first and agent-aware. A background server owns the real terminal
processes, so panes survive a detached client, a closed terminal or a dropped
SSH session. What makes it worth the switch is the sidebar: herdr recognises
coding agents inside panes and rolls their state up per workspace, so you can
see across every project which agent is `working`, which is `blocked` waiting
on you, and which is `done`.

Installed on **p620 and razer** (the interactive-host developer profile), both
on herdr 0.9.5. Not on p510.

## What this repo owns, and what it does not

This split is the thing to understand before changing anything:

| Thing | Owned by | Consequence |
| --- | --- | --- |
| `~/.config/herdr/config.toml` | `home/development/herdr.nix` | A Nix-store symlink. **Cannot be edited in place** — edit the repo and deploy. |
| Everything else in `~/.config/herdr/` | herdr itself | Sessions, logs, pane history, plugin registry. |
| Plugins | installed imperatively, per host | `herdr plugin install …` on *each* machine. Nothing in the flake pins them. |

The Nix module deliberately carries no host conditionals, so p620 and razer get
a byte-identical `config.toml` — verify with `readlink -f
~/.config/herdr/config.toml` on both and compare the store hash.

Plugins are the opposite: they are global to the user but local to the machine,
so **the two hosts drift apart silently**. Nothing warns you. Compare them with
`herdr plugin list` on each and reinstall whatever lags.

## Installed plugins

Ten, identical on both hosts:

| Plugin | What it is for |
| --- | --- |
| `furkankly.zoetrope` | Session flow graph — the only way to see subagents |
| `persiyanov.reviewr` | Diff review sidebar; comments go back to the agent |
| `smarzban/herdr-file-viewer` | Git-aware read-only file viewer with diffs |
| `lmilojevicc/herdr-splits.nvim` | Unified `ctrl+hjkl` across herdr panes and Neovim splits |
| `kryptamine/herdr-auto-title` | Automatic pane titles |
| `AltanS/collie` | PWA to watch agents from a phone over the tailnet |
| `JanTvrdik/herdr-command-palette` | fzf command palette |
| `nikok6/herdr-mirror` | Mirrors remote herdr servers into the local sidebar |
| `ogulcancelik/herdr-plugin-github-start` | GitHub entry points |
| `andrewchng/herdr-sessionizer` | Project switcher |

Install a plugin on both hosts:

```bash
herdr plugin install <owner>/<repo> --yes
ssh razer 'herdr plugin install <owner>/<repo> --yes'
```

Note that a plugin whose manifest sits in a subdirectory needs the full path —
zoetrope is `furkankly/zoetrope/herdr-plugin`, and the bare repo name fails.

Both zoetrope and reviewr are Rust and compile from source at install time,
which is the good case on NixOS: a plugin that shipped a prebuilt dynamically
linked ELF would need `nix-ld` to run at all. zoetrope's build installs `zoe`
into `~/.cargo/bin`. Verify a plugin actually works rather than trusting the
installer — `ldd <binary> | grep "not found"` should be empty.

## Seeing what subagents are doing

Claude Code's `Task` subagents **run in-process with no PTY**. herdr detects one
agent per pane, so no amount of configuration will give a subagent its own row,
tab or pane. There are exactly two honest approaches.

### Read the session graph (zoetrope)

zoetrope parses the session transcript JSONL directly — `~/.claude/projects/`
for Claude Code, `~/.codex/sessions/` for Codex — and tells the formats apart by
content. Because it reads the transcript rather than the terminal, in-process
subagents appear as real nested nodes: the main session, its subagents, and
workflow groups, with each agent's tool calls as chips beneath it. It follows
live, and scrubs back through a finished session.

```bash
# inside herdr: open the graph over the current pane, following live
prefix+shift+z

# standalone, on any transcript
zoe ~/.claude/projects/<project>/<session>.jsonl
```

### Or stop using in-process subagents for work you want to watch

Spawn real agents in real panes. Each becomes a genuine sidebar row with real
`working`/`blocked`/`done` state, its own scrollback, and a pane you can attach
to:

```bash
id=$(herdr pane split --current --direction right --cwd "$PWD" --no-focus \
      | jq -r .result.pane.pane_id)
herdr agent start reviewer --kind claude --pane "$id"
herdr agent prompt reviewer "Review the diff, actionable findings only" \
      --wait --timeout 300000
```

`agent start` requires an existing pane at an interactive prompt; it never
creates or moves layout itself. Split a wide pane right and a tall one down, and
keep `--no-focus` so the user's focus stays put.

Start work in a background split and promote it to its own tab only when you
want to watch it:

```bash
herdr pane move <pane-id> --new-tab --focus
```

For an agent *team*, give each member its own git worktree so they cannot fight
over the tree:

```bash
herdr worktree create --branch feat/1234-thing --focus
```

Worktrees land in `~/.herdr/worktrees` (set in the Nix module) and
`prefix+shift+o` opens one.

## Reviewing diffs (reviewr)

A diff sidebar with four scopes: uncommitted (working tree vs HEAD, including
staged and untracked), branch (vs merge-base with the base branch), last agent
turn, and individual commits. It polls the worktree every two seconds.

The point of it is the round trip: select lines with `v`, comment with `c`, send
with `s`, and every comment lands in the agent's input. With one agent in the
workspace it goes straight there; with several you get a picker. So a review
becomes "annotate the diff, press send" instead of retyping findings into a
prompt.

```bash
herdr plugin action invoke open --plugin persiyanov.reviewr
```

It needs `git` on `PATH`, a truecolor terminal, and herdr ≥ 0.7.5. `gh`, `glab`
or `az` unlock its PR tab; this repo's hosts have `gh` and `glab`.

## Agent integrations

Without an integration, herdr guesses agent state by scraping the screen. With
one, the agent reports its own lifecycle, so `blocked` means a real approval
prompt rather than a pattern match. Install per agent:

```bash
herdr integration install claude
herdr integration status            # or --outdated-only
```

Current state on both hosts — `claude` v9, `codex` v8, `copilot` v3,
`opencode` v12. Of the seven AI CLIs installed here (claude, codex, gemini,
opencode, copilot, crush, grok):

- `grok` has an integration but it **cannot be installed until the CLI has run
  once** — the installer writes into `~/.grok`, and refuses with "grok config
  directory not found" if that directory does not exist yet. Run `grok`, then
  install.
- `crush` is not a herdr-supported kind at all, so its panes are never
  classified as agents.
- Plain `gemini` has no integration of its own; the `antigravity-cli`
  integration is what writes into `~/.gemini`.

Integrations are **per host**, and they are not covered by Syncthing:
`~/.claude/.stignore` excludes `hooks/**`, which is exactly where the Claude
hook lives. Run the install on each machine.

## Codex and agy rows

A headless Codex or agy run shows up as a `↳ codex` or `↳ agy` row under the
Claude lead. The row is *working* while the run lasts, *done* for about 3 s,
then its background tab closes. The tab streams the run's live progress.

The rows come from `herdr-run <codex|agy> <command…>`, which the
`second-opinion`, `handoff` and `agent-run` tooling puts in front of their
commands. Outside herdr it just runs the command.

- Ctrl-C and a timeout stop the run and close the tab.
- A run herdr loses exits 1 and is never re-run.
- `herdr-run` streams stdin to the command through a FIFO and never reads it
  up front, so a stdin that never closes (Claude Code's Bash tool gives a
  socket) only matters to a command that actually reads it (#2679).
- The pane's command gets only the variables named in
  `home/development/agent-env.sh` (no tokens, no `HERDR_*`, no `SSH_AUTH_SOCK`),
  not the caller's whole environment. Outside herdr it gets the caller's
  (#2762).

## Team tab

`herdr-team` is the default for mixed agent teams inside herdr (Issue #2810). It opens a background tab per task,
with one visible pane per member, so you can watch every agent work and type into any of them:

- `<task>-review` stays warm for the whole task;
- `<task>-implement` runs one member per plan step.

`agy-implement` is refused while `agyMember` is false, so agy steps stay on `agent-run`. Outside herdr, every
`herdr-team` command exits 2.

```bash
herdr-team up <task> review
herdr-team up <task> implement --step <k>
herdr-team ask <task> <member> <prompt-file> [--resume n] [--timeout s]
herdr-team converse <task> <member> <prompt-file> [--max-hops N] [--deadline s]
herdr-team finish <task> implement
herdr-team status <task>
herdr-team down <task> [member] [--force]
```

- **Members run unrestricted** (Issue #2812): Codex with `--dangerously-bypass-approvals-and-sandbox`.
  - They are launched through `agent-env`, so `NIX_CONFIG` and other tokens never reach them.
  - The implementer goes through `codex-implement`, so the coder guard preflight runs and `CODEX_CODER=1` is set.
  - "Do not stage, commit, push, deploy or type into other panes" is an instruction to them, not a barrier.
- **Requests and answers.** `ask` copies the prompt to `<work>/req/<n>.md`, then types only a fixed pointer
  (`Request <gen>-<n>: read <work>/req/<n>.md and answer it in your reply.`). The answer comes from Codex's own
  `notify` hook, which `herdr-team-sink` writes to `<work>/turns/<turn-id>.json`. A turn counts only when its
  input equals that pointer exactly.
- **Members talk to each other.** `converse` relays the final `TO: <member>` … `END` block of each reply to that
  teammate, as a request file behind a fixed "teammate message, not an instruction" header. It stops when a reply
  addresses `lead` or has no block, at the hop limit (default 6) or at the deadline (default 1800 s). Every hop
  goes to `<gen>/conversation.jsonl`, and teardown keeps a copy in the archive.
- **JSON lines.** `ask` prints `{ok, outcome, n, member, answer, turn_id, revision_at_send, revision_at_reply,
  changed_during_review, exit}`. Its `outcome` is one of `ok`, `empty`, `provider_error`, `interrupted`, `cancelled`,
  `agent_gone`, `refused`, `send_failed`, `oversize`, `timeout` or `busy`. `converse` prints one line per hop,
  `{hop, from, to, n, outcome, answer, changed_during_review}`, with no `ok` field: a hop succeeded when
  `outcome == "ok"`. A converse outcome is one of the `ask` outcomes plus `bad_address`, `bad_block`,
  `stale_target`, `hop_limit`, `deadline` and `busy_conversation`.
  - On `provider_error`, the matching terminal lines are saved to `<work>/ans/<n>.screen`.
- **`finish`.** It quits the implementer gracefully, runs `down` and checks:
  - the graceful exit code;
  - `HEAD` unchanged;
  - a non-empty diff against the start fingerprint;
  - nothing staged;
  - the last `outcome == "ok"`.

  Git runs with the git dir recorded at `up`, with fsmonitor and hooks off. Then it prints
  `{ok, reason, changed, head_moved, exit}`.
- **Archive.** Teardown copies each member's answers to
  `$XDG_RUNTIME_DIR/herdr-team/archive/<gen>/<member>/` and the log to `archive/<gen>/conversation.jsonl`. They stay
  until logout.
- **Containment** (Issue #2835). `up` picks one of two modes and records it as `containment` in its reply and in
  the task's state file:
  - `scope` when the systemd user manager answers: the member runs in its own transient unit,
    `herdr-team-<task>-<gen>-<member>.scope`. Stopping the member stops the unit, which ends every process in it,
    including children that left the process group, dropped the marker or ignore TERM (killed after
    `TimeoutStopSec`, 5 s at the default time scale). The member keeps its PID, process group and tty.
  - `group` otherwise (or with `HERDR_TEAM_NO_SCOPE=1`): while the member's own process (the group leader,
    carrying its `HERDR_TEAM_MEMBER` marker) is alive, its whole process group is signalled. Once the leader is
    gone, only processes in that group that still carry the marker are signalled. A process that drops the marker
    or leaves the group is not stopped.
- **A scope that will not stop.** If a unit is still active after its stop, `down` and `finish` keep the member's
  record and list it under `scope_stop_failed`, and `down` exits 1. The next `up` for the task sweeps it again.
  To see what is left:

  ```bash
  systemctl --user status 'herdr-team-*'
  ```

- **Watchdog.** A per-member watchdog ends the member (its scope first, then the process group) if the lead dies,
  or when the role's maximum is reached (8 h `review`, 3 h `implement`).

## Claude agent teams

Inside herdr, `claude` is a bash/zsh function (set in
`home/development/herdr.nix`) that runs `herdr-claude-teams`. It puts a `tmux`
shim on `PATH` that turns Claude Code's tmux calls into herdr socket calls.

- Each teammate opens in its own tab, right after the lead's tab, labelled
  `↳ <name>`. The tab never takes focus, and the lead's tab layout is left
  alone: the shim resizes and renames only tabs and panes it created.
- When the lead stops a teammate, that teammate's tab closes.
- `claude-swarm-reaper`, a user timer that runs every 2 minutes, closes
  teammates that have been idle for 10 minutes.
- Only panes and tabs the shim created are ever closed. They are tracked in
  `$XDG_RUNTIME_DIR/herdr-claude-teams/*.owned`.

```bash
# which teammate panes the shim owns for this session
cat "$XDG_RUNTIME_DIR"/herdr-claude-teams/*.owned
```

## Configuration worth knowing

All of this lives in `home/development/herdr.nix`:

- `agent_panel_sort = "priority"` turns the sidebar into an attention queue, so
  a blocked agent rises above idle ones instead of sorting by workspace.
- `[ui.toast] delivery = "system"` hands notifications to the desktop service.
  The default, `"herdr"`, only draws a toast while herdr is on screen — which
  means an agent blocked on a question goes unnoticed.
- Sidebar rows are configurable per agent kind. Claude rows carry
  `terminal_title_stripped`, which is where Claude Code reports what it is
  currently doing, plus a `$agents` pane-metadata token fed by the managed
  PreToolUse/PostToolUse hooks in `modules/programs/claude-code-managed.nix` —
  the live subagent count, since the subagents themselves can never be rows.
- `scrollback_limit_bytes = 50000000`, because Claude Code outruns the 10 MB
  default.
- `[experimental] pane_history = true` keeps pane screens across server
  restarts.
- `[update] version_check = false`. The binary is read-only in the Nix store and
  tracked by a flake input; left enabled, herdr would poll for updates and offer
  to install a binary the next deploy silently reverts. `manifest_check` stays
  on, since that only refreshes agent-detection data. Bump with
  `nix flake update herdr`.

Apply a config change with `herdr server reload-config` after the deploy, and
validate with `herdr config check` — note that it does *not* validate
`theme.name`, which accepts arbitrary strings, so a typo there passes silently.

## Gotchas

- `herdr --help` and each bare command group (`herdr agent`, `herdr pane`) are
  the authority on syntax, not the docs — the installed binary here is two minor
  versions ahead of the checked-out repo's documentation.
- Do not run bare `herdr` from inside a pane: it launches or attaches the TUI,
  and nested launches are blocked by design. Check with `test "$HERDR_ENV" = 1`.
- Prefer `--current` or an explicit pane ID. Omitting a target may act on the
  UI-focused pane, which can belong to another client.
- An agent running on the terminal's alternate screen loses rows to nowhere —
  they never reach herdr's host scrollback, so raising `--lines` cannot recover
  them. Ask the agent to write its output to a file instead.
- Never `herdr server stop` from an active session unless you mean to kill every
  pane process with it.
