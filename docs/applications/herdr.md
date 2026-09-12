# Herdr

A terminal workspace manager for coding agents — a multiplexer like tmux, but
mouse-first and agent-aware. A background server owns the real terminal
processes, so panes survive a detached client, a closed terminal or a dropped
SSH session. What makes it worth the switch is the sidebar: herdr recognises
coding agents inside panes and rolls their state up per workspace, so you can
see across every project which agent is `working`, which is `blocked` waiting
on you, and which is `done`.

Installed on **p620 and razer** (the interactive-host developer profile), both
on herdr 0.9.0. Not on p510.

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
