---
status: approved
issue: 2978
intent: intent/2026-11-16-2978-herdr-app-parity.md
---

# Spec: herdr-app parity with the TUI workflow, plus an issues and agent-team overview

## Approved intent decisions

The owner approved the intent with "use your recommendations where needed,
we can create what is needed or even create our own plugins". The open
questions are settled as follows:

1. **Parity:** a function counts as carried over only when it works inside
   herdr-app. The TUI stays installed and unchanged. Anything not in the app
   after this task is in "Gaps", with a follow-up issue each. The owner
   accepts those gaps by approving this spec.
2. **Agent control:**
   - Every agent with an hc terminal gets full control.
   - Claude Task subagents have no terminal of their own: they are shown (a
     count and the zoetrope graph) and controlled through their parent.
   - The view covers every hc machine.
3. **Teams:** `herdr-team`, `herdr-run` and `herdr-claude-teams` get an hc
   backend. The TUI backend stays as it is.
4. **Issues:** one inbox across GitHub (all repos) and gitlab.com:
   - What: issues and PRs/MRs assigned to the owner, opened by them, or
     waiting on their review.
   - Actions: open in the browser, or start an agent on one.
   - The inbox itself is read-only. Per-repo panels add native write
     actions, and only on a button press.
5. **Our own mods:** yes.
6. **TUI plugins:** unchanged, still installed by hand on each host.

## Facts this design rests on

Checked on p620 on 2026-11-16 with app 0.1.15 / core 0.1.20, unless
marked otherwise.

- **Agent status works natively in hc.** `hc run --bg` of `claude`,
  `codex --no-daemon` and `agy` reported `idle`, `idle` and `blocked` (agy's
  folder-trust prompt) through OSC 7501, with no hooks.
  - The `herdr integration` hooks are TUI-only: they need `HERDR_PANE_ID`
    (herdr-app#358).
- **Inside an app terminal** there is no `HERDR_ENV`; there is
  `HC_TERMINAL_ID`, `HC_TERMINAL_SOCKET` and `HC_SCOPE`. `agent-env` drops
  `HC_*` (`home/development/agent-env.sh:11`).
- **The app owns `~/.config/herdr-app`:**
  - It rewrites its shipped mods and layouts on every start.
  - It writes `settings.json`, `keys.json`, `shared.json`, `data/`,
    `layouts/.state/` and `view.json`, and reloads files live.
  - Mods with new names are left alone.
  - `keys.json`: once edited, it is the person's, and new upstream defaults
    are no longer added.
- **Commands checked** (Codex review and `herdr-app commands`):
  - App commands: `terminal.open {argv, folder, place: tab|right|down,
    name}`, `terminal.keep {terminal, place}`, `tab.new {name, space, folder,
    argv, task}`, `pane.go {direction}`, `space.new {…, argv, task}`.
  - Mod and layout APIs: `setAgentOrder`, `program.key`, and the layout-root
    `toast`.
  - hc: `run --bg --keep --name --cwd --label`, `get`, `read`, `send`,
    `keys`, `interrupt`, `kill`, `exec --on <machine>`.
  - A terminal labelled `herdr.space=<id>` and `herdr.tab=<id>` shows up in
    that tab (app manual).
  - `tab.new` with `argv` runs it inside an interactive shell that stays
    open; a program's exit closes its pane.
- **Status records:** OSC 7501 `id=` records are extra records inside one
  terminal. Parent/child rows come from hc's `parent` (the terminal that ran
  `hc run`).
- **hc** keeps each terminal's holder in its own `hc-hold-*` user unit. Its
  config file, `~/.config/herdr-core/config.toml`, is only read; machines
  live in `~/.local/state/herdr-core`. Codex must run with `--no-daemon`
  under hc.
- **Theme:** Omarchy's `omarchy-theme-set-herdr-app` writes
  `themes/omarchy.json` on every theme change. `"theme": "omarchy"` in
  `settings.json` makes the app follow it.
- **Upstream** is at app 0.1.16 and core 0.1.21 (`releases.herdr.dev`).
  0.1.21 adds `restore_screen`.
- **Codex research** of 927 repos: GitHub and GitLab panels exist, but only
  for the focused repo. No mod gives full agent control.

## Design

Six parts, each deployable on its own, in this order. Parts 5 and 6 each
start with a spike whose result can change their details. A spike that
fails stops that part and is reported, not worked around.

### Part 1: packages and hc config

- **Bumps:** core 0.1.20 → 0.1.21 and app 0.1.15 → 0.1.16, in
  `pkgs/herdr-{core,app}/default.nix`. The hashes come from the release
  manifests, and #2861's update checks are re-run.
- **hc config:** `home/development/herdr.nix` gains
  `xdg.configFile."herdr-core/config.toml"`:
  - `history_mb = 48`: about the TUI's `scrollback_limit_bytes = 50000000`.
  - `restore_screen = true`: the closest match to `pane_history`.
- No shell wrapper: hc's per-terminal units cover #2959. Verification 7
  checks this.

### Part 2: app config, declared, applied by `herdr-app-sync`

`pkgs/herdr-app-sync/` is a `writeShellApplication` with `jq`, `rsync` and
`coreutils`. It runs in two places:

- from a Home Manager activation step in a new
  `home/development/herdr-app.nix` (imported next to `herdr.nix`, gated the
  same way);
- at every app launch: `pkgs/herdr-app`'s wrapper runs it before `exec`.

So a host where the app was never opened converges on the first launch,
and no app state exists before that. The step never fails activation or
launch: it logs to the journal (`systemd-cat -t herdr-app-sync`) and exits 0.

Inputs: a store directory with `mods/<name>/`, `layouts/freund.json`,
`settings.json` (our keys), `keys.json` (our sections) and `managed.json`
(the managed names). State, outside the app home:
`~/.local/state/herdr-app-sync/manifest.json` holds a sha256 per managed
file as last installed, plus `backups/<time>/`.

**For each managed mod or layout:**

| On disk | Manifest | Action |
|---|---|---|
| absent | any | install |
| present | no entry | move to `backups/<time>/`, install (first take-over) |
| present, matches the manifest | entry | install only if the source changed |
| present, differs from the manifest (local edit) | entry | move to `backups/<time>/`, install, log the backup path |

**Install is atomic:**

1. Copy into `mods/.sync-<name>.<pid>/`.
2. `herdr-app check` that folder.
3. On success, `rename` the old folder into the backup area and the new one
   into place, then update the manifest.
4. On failure, the old mod stays and the error is logged.

A layout is one file and goes through the same steps, via a temp file and
`rename`.

**`settings.json` and `keys.json`:**

- Read, `jq` merge (our keys win, everything else kept), write to a temp
  file, `rename`. If the file is invalid JSON it is left untouched and
  logged.
- A key the owner changes in the app wins until the next sync, which puts
  ours back. That is the rule for every declared key; undeclared keys are
  never touched.
- Taking over `keys.json` stops upstream adding new default keys (the
  upstream rule). Each app bump checks the new defaults in the plan's bump
  checklist.

**Third-party mods** are fetched with `fetchFromGitHub` and pinned to a
commit. No installer scripts and no `git pull`.

**Layout `freund`:**

- Made once with `herdr-app do layout.clone '{"name":"main","as":"freund"}'`
  on 0.1.16, edited, and saved as
  `home/development/herdr-app/layouts/freund.json`.
- Root `"toast": "notify"`.
- The sidebar's agents block uses our `freund-agents` mod (Part 3).
- The tab bar is our clone `freund-chrome` (of `workspace-chrome`), with
  Issues and GitLab buttons next to Files and Changes. The plan takes the
  exact change from the two third-party mods' own layout diffs.
- `settings.json` can't pick a layout, so the sync runs
  `herdr-app do layout.switch --name freund` once, when the app is running
  and the manifest says this is the first install. `ctrl-shift-l` still
  cycles back to `main`.
- Every app bump re-clones `freund-chrome` and `freund-agents` from the new
  shipped mods and re-applies our diff (plan checklist), because clones get
  no upstream fixes.

### Part 3: mods

| Mod | Source | What it gives |
|---|---|---|
| `issues` | jankeesvw/herdr-issues @15ffaad0, MIT | the focused repo's GitHub issues: filters, timeline, comment and close on a button (`gh`) |
| `gitlab` | rem-aster/herdr-gitlab @dc4931a0, MIT | the focused repo's GitLab issues, MRs, pipelines; approve and merge on a button (`glab`) |
| `resize` | jmayaalv/herdr-app-resize @4a3b91b1, MIT | keyboard resize of app panes |
| `inbox` | ours | cross-repo inbox |
| `freund-agents` | ours: clone of shipped `agents` | every agent and team, with control |
| `notify` | ours | alerts to the desktop |
| `splits` | ours | ctrl+hjkl and alt+hjkl across app panes and Neovim |

Mods that run programs (Codex research, checked against each README):
`issues` runs `gh` and `hc read`; `gitlab` runs `git`, `glab`, `sh` and
`sed`. All of ours run `gh`, `glab`, `hc`, `herdr-app`, `notify-send` or
`xdg-open`. None stores a token.

**`inbox`:**

Queries:

| Provider | Kind | Filters |
|---|---|---|
| GitHub (`gh search`) | issues | `--assignee=@me`, `--author=@me` |
| GitHub | PRs | `--assignee=@me`, `--author=@me`, `--review-requested=@me` |
| gitlab.com (`glab api --paginate`) | issues | `scope=assigned_to_me`, `scope=created_by_me` |
| gitlab.com | MRs | `scope=assigned_to_me`, `scope=created_by_me`, `reviewer_username=<me>` |

- All queries are open items only. Each is capped at 100 (`gh search
  --limit 100`, `per_page=100` with at most 3 pages). A capped list says
  so: "showing 100 of more, open on the web".
- Rows are merged by ID (`gh:owner/repo#12`, `gl:group/proj!7`). One row
  carries every reason it matched (assigned, author, review).
- Each provider shows its own error (logged out, offline), and the other
  keeps working.
- Refresh: every 5 minutes and on demand.
- **Open** runs `xdg-open <url>`.
- **Start agent:**
  - Find a local clone: a space whose terminals are already in that repo
    (remote URL match), else under the roots listed in the mod's `mod.json`
    (`~/.config`, `/mnt/code`), checked by `git remote -v`.
  - Then `space.new {folder, argv: ["claude"], task: "Work on <url>"}`,
    which leaves branch and worktree to Claude and the repo rules.
  - No clone found: a toast, and nothing starts.
- The inbox never writes to GitHub or GitLab.

**`freund-agents`** (a `mod.clone` of the shipped `agents` mod, so there is
one agent list and one owner of `setAgentOrder`):

- **Keeps** the shipped list: status, groups, icons, and children under
  their parent (sub-agents from `hc run`, team members, Claude teammates).
- **Adds a row menu** with the controls each row really has:
  - Focus (`agent.focus`) and Peek (`terminal.peek`): peek shows the real
    terminal, so a blocked prompt is answered there.
  - Send (a prompt line, then `hc send <machine/address>`), and Interrupt
    (`hc interrupt`).
  - Stop (`terminal.kill`, after a confirm).
  - Pane (`terminal.keep`) / Hide (`terminal.park`).
- **Adds a "Task subagents: N" line** under a Claude row, with a **Graph**
  button: `terminal.open {argv: ["zoe", <cwd>], place: "right"}` in that
  agent's own tab. Terminals in a remote space start on that machine, so
  zoe reads that machine's transcripts. The line has no controls: they go
  through the parent.
- **Where the count comes from.** The hook in
  `modules/programs/claude-code-managed.nix:687` gains an hc branch:
  - When `HC_TERMINAL_ID` is set and `HERDR_ENV` is not, it keeps the same
    locked counter (`:702`), keyed by `HC_TERMINAL_ID`.
  - It also writes `$XDG_RUNTIME_DIR/claude-hc-subagents/<HC_TERMINAL_ID>`
    as `{count}`.
  - The mod reads it on the agent's own machine with
    `hc exec --on <machine> cat <file>`, or a local `cat` when local.
  - It shows the count only while that terminal is live with status
    `working`, so counts don't need a timeout.
  - The TUI branch is unchanged.

**`notify`** (place `none`, named by the layout's root `toast`):

- Each toast goes to `notify-send -a Herdr -A open=Open <title> <body>`,
  run detached through `sh -c`. If `open` is clicked:
  `herdr-app do agent.focus --terminal <t>`.
- It closes its overlay at once.
- The app's sound still plays.

**`splits` + Neovim:**

- **App side.** `keys.json`'s `terminal` section binds `ctrl-h/j/k/l` to
  `splits.go-*` and `alt-h/j/k/l` to `splits.resize-*`. The mod reads the
  focused pane's `program.key`:
  - `nvim`: forward the key unchanged with `hc keys <t> ctrl+h` (or
    `alt+h`). Neovim then decides, so its own exclusions still apply:
    terminal buffers, pickers, help and sidebars keep the key.
  - Otherwise: `go` → `run("pane.go", {direction})`; `resize` → the
    `resize` mod's command.
- **Neovim side** (`home/shell/lazyvim/lazyvim/lua/plugins/herdr-splits.lua`):
  - One plugin spec with `cond = HERDR_ENV == "1" or HC_TERMINAL_ID ~= nil`.
  - The same `ignored_buftypes` / `ignored_filetypes`.
  - Its key functions call herdr-splits in the TUI, and our module in the
    app. That module does `wincmd` / `resize` inside Neovim; when the
    cursor is at the edge it runs
    `jobstart({"herdr-app","do","pane.go","--direction",dir})` (go), or
    nothing (resize).
- **Same trade-off as the TUI today:** ctrl+l doesn't clear the screen in
  shells.
- **Exception to "never move an app default":** alt+hjkl replaces the
  app's `pane.go` on purpose, because ctrl+hjkl now does that and the TUI
  habit is alt = resize.

### Keys (our `keys.json` sections)

| TUI | App key | Action |
|---|---|---|
| ctrl+hjkl | `ctrl-h/j/k/l` (terminal) | `splits.go-*` |
| alt+hjkl | `alt-h/j/k/l` (terminal) | `splits.resize-*` (exception above) |
| prefix+[ / ] | `alt-up` / `alt-down` | app default, nothing added |
| prefix+alt+g lazygit popup | `ctrl-shift-g` | `terminal.open {argv: ["lazygit"], place: "tab"}`: closes when lazygit exits |
| prefix+k / prefix+space | `ctrl-?` / `ctrl-shift-p` | app defaults `app.help` / `app.palette` |
| prefix+shift+z / prefix+alt+z zoetrope | `ctrl-shift-y` / `ctrl-alt-shift-y` | `terminal.open {argv: ["zoe"], place: "right"}` / `place: "tab"` |
| prefix+shift+o open worktree | `ctrl-shift-u` | `mod.open` of `worktree` with `{action: "open"}` |
| new | `ctrl-shift-i` | `mod.open:inbox` |

Every key except alt+hjkl is free in 0.1.15's defaults. The plan
re-checks against 0.1.16; a clash moves our key.

### Part 4: the baseline, TUI → app

| TUI function | In herdr-app | Part |
|---|---|---|
| herdr-radar (agent sidebar, logos, tab bar) | shipped list in `freund-agents` (status, groups, icons, children) | 2, 3 |
| zoetrope (overlay, split, tab) | `zoe` via keys and the Graph button | 3 |
| reviewr: diff view | shipped `changes` mod | — |
| reviewr: send line comments to the agent | **gap** | follow-up |
| herdr-splits (nav + resize, Neovim) | `splits` + `resize` + Lua | 3 |
| hintr | `app.help` lists keys but doesn't run them: **partial gap** | follow-up |
| pretty-which, command palette | `app.palette` | — |
| sessionizer | shipped `worktree` mod + `ctrl-shift-u` | — |
| auto-title | 0.1.16 names tabs after the agent's session | 1 |
| collie | **gap** (ColliePWA's hc adapter is experimental) | follow-up |
| mirror | hc machines, already in use | — |
| file viewer | shipped `files` mod | — |
| GitHub Start | `issues` + `inbox` | 3 |
| lazygit popup | `ctrl-shift-g` (a tab, not a float: there is no float place) | 2 |
| system notifications, sounds | `notify` mod; `settings.sounds` | 2, 3 |
| live Omarchy theme | `theme: "omarchy"` + Omarchy's script | 2 |
| status symbols, labels, teammate order | shipped list (icons and status text, children under parent) | 3 |
| window title `{hostname}: {workspace}` | **gap**: no title setting; the list names the machine | follow-up |
| worktree folder | the shipped mod uses the same `~/.herdr/worktrees` | — |
| per-pane systemd scope | per-terminal `hc-hold-*` units | 1 |
| 50 MB scrollback, pane history | `history_mb`, `restore_screen` | 1 |
| agent-state integrations | native OSC 7501 | — |
| `herdr-team`, `herdr-run` | hc backend | 5 |
| `herdr-claude-teams` | hc backend | 6 |
| subagent-count hook | hc branch | 3 |
| Omarchy `nixarchy.herdr` widget | **gap**: lives in the nixarchy-herdr repo | follow-up |

### Part 5: hc backend for `herdr-team` and `herdr-run`

**Spike first** (from an app terminal, scratch names), proving four things:

- a labelled `hc run --bg --keep` lands in a given tab without moving
  focus;
- it has the lead as `parent`;
- `herdr-app ls` shows it in that tab;
- `hc kill` removes it cleanly.

If labels don't place it, the fallback is `terminal.keep {terminal,
place: "tab"}` followed by `space.select` / `tab.select` back to the lead.
The spike's result goes into the plan.

**Backend choice:**

| Environment | herdr-team | herdr-run |
|---|---|---|
| `HERDR_ENV=1` with socket and IDs | TUI (today's code, byte-identical) | TUI |
| else `HC_TERMINAL_ID` set | hc | hc |
| else | "not inside herdr" error (today) | `exec "$@"` (today) |

**hc launch sequence for a member** (replaces the create-then-write order):

1. Write the work dir and the `launch` script first. The script reads its
   own `HC_TERMINAL_ID` at runtime, so it needs no identity baked in.
2. Create the team tab once per task: `herdr-app do tab.new --space <lead
   space> --name "team <task>" --argv '["true"]'`. The lead's space comes
   from `herdr-app ls` for `$HC_TERMINAL_ID`; the placeholder shell exits
   at once.
3. `hc run --bg --keep --name <task>-<role> --cwd <root> --label
   herdr.space=<S> --label herdr.tab=<T> -- bash <launch>`. hc returns the
   address, which is saved in the member record. Codex members get
   `--no-daemon`.
4. Readiness:
   - `hc get <t> --json` until the status is reported and the foreground is
     the expected program;
   - the record's address equals the reply's;
   - the program is the expected agent.

   These replace today's `.result.pane.terminal_id` / `.agent` /
   `.agent_session` checks one for one.
5. If placement or readiness fails, `hc kill <t>`, remove the record, and
   fail as today.

**Verb map (hc backend):**

| Today (TUI) | hc |
|---|---|
| `pane get` (identity, agent) | `hc get <t> --json` (`address`, `foreground`, `status`) |
| `pane read --source visible` | `hc read <t> --lines <n>` |
| `pane send-text` + `send-keys enter`, `agent prompt` | `hc send <t>` |
| `pane send-keys ctrl+c`, `agent send-keys ctrl+c` | `hc interrupt <t>` |
| `pane close` | `hc kill <t>` (only an address in our record) |
| `pane rename`, `agent rename` | the name given at `hc run --name` |
| `tab create`, `pane split`, `pane run` | the launch sequence above |
| herdr-run `tab.list` / `pane.list` / `tab.move` (direct socket, `herdr-run.sh:216`) | none needed: placement comes from labels |
| herdr-run `report-agent` / `release-agent` / `report-metadata` | the runner is its own hc terminal (a child of the caller, so it shows under the lead); it writes OSC 7501 `working` / `done` / `error` to its own tty |

Unchanged in both backends:

- answers from Codex `notify` turn files;
- converse hop and deadline limits and the audit log;
- `finish` checks (repair retries, staged changes, moved HEAD);
- the watchdog;
- systemd scopes;
- `agent-env` (members don't need `HC_*`: the script runs in the lead's
  environment, not through `agent-env`);
- refusing a dirty tree;
- for `herdr-run`: stdin, stdout and stderr passed through separately, the
  exit status, and cancellation.

**Tests:** `herdr-team-test.sh` and `herdr-run-test.sh` gain hc cases with
fake `hc` and `herdr-app` on `PATH`, matching the fake `herdr` they use now:

- cancel, stdin open, separate stderr;
- lead death, timeout cleanup, failed placement;
- a duplicate launch refused;
- refusing to kill an address not in the record;
- staged changes and moved HEAD in `finish`.

### Part 6: hc transport for `herdr-claude-teams`

**Spike first:** a Claude agent team with two teammates in an app terminal
through a prototype transport, run against the pinned shim's test suite.

New patch `pkgs/herdr-claude-teams/hc-backend.patch`:

- **Leader** = `HC_TERMINAL_ID`. **Ownership:** a state file under
  `$XDG_RUNTIME_DIR/herdr-claude-teams/<leader>.json` lists the addresses
  the shim created. Every kill or respawn checks it, as `ownership.patch`
  does today with `HERDR_PANE_ID`, so an unrelated terminal is refused.
- **`split-window`** follows `teammate-tabs.patch`'s behaviour: an unfocused
  tab after the lead's, named for the teammate. That is `tab.new` with a
  `["cat"]` placeholder, then the teammate's own `hc run` labelled into that
  tab. Fake `%N` pane IDs map to hc addresses.
- **`respawn-pane`:** `hc interrupt` the `cat` placeholder, wait (`hc get`)
  until its foreground is no longer `cat`, then `hc send` the command, as
  `ownership.patch:180` does.
- **The rest:** `send-keys` → `hc keys` / `hc send`; `capture-pane` →
  `hc read`; `kill-pane` → `hc kill`; `list-panes` / `display-message` →
  `hc ls --json`, filtered to the owned set.
- **`claude()`** in `home/development/herdr.nix` routes to
  `herdr-claude-teams` when `HC_TERMINAL_ID` is set too.
- **Until this part ships,** Claude teams in the app run in-process, which
  is today's behaviour outside herdr.
- **Tests:** the package's pytest suite gains hc-transport cases with a
  fake `hc` and `herdr-app`, including refusing an unowned address.

## Gaps (follow-up issues, the owner accepts them with this spec)

- reviewr's send-comments-to-agent flow (a custom mod).
- hintr's "press a listed key to run it" (`app.help` only lists keys).
- `nixarchy.herdr` Omarchy widget: an hc adapter, in the nixarchy-herdr repo.
- Window title with host and workspace (upstream request).
- Collie through `COLLIE_MUX=herdr-core`, when it is no longer experimental.
- The lazygit popup is a tab: the app has no floating terminal place.

## Alternatives rejected

- **Store symlinks for mods, layouts or keys:** the app writes into
  `mods/`, `keys.json` and `settings.json`. A symlinked mod works for
  herdr-issues, but not for issue-launcher.
- **Mods' own installers** (`install.py`, `install.sh`, `git pull`): not
  declarative, and they edit shipped layouts.
- **A second agent list next to the shipped one:** both would call
  `setAgentOrder`, so the last to render would own next/previous. One cloned
  list owns it.
- **Mission Control, issue-launcher, Agent Map, herdr-bg-activity:** wider
  footprints (Node or Python helpers, resume hooks), focused-repo only, or
  visibility only.
- **herdr-redline:** no license detected.
- **OSC 7501 `id=` records for herdr-run rows:** they are records inside
  one terminal, not rows with their own address. A real child terminal is.
- **Setting `HERDR_ENV` so TUI plugins run in the app:** a different
  protocol, and it could drive a live TUI session by mistake.

## Risks

- **0.1.x churn:** cloned and third-party mods follow app internals. The
  sync checks every mod before publishing, keeps the last good one, and each
  bump runs Verification 3-5.
- **`resize`** edits an undocumented document shape. If it breaks, alt+hjkl
  falls back to the app default by removing one binding.
- **Key forwarding to Neovim** adds one `hc keys` round trip per keypress.
  Verification 4 checks the lag.
- **The team tooling backends:** the TUI path stays byte-identical
  (checked by diffing it out of the script), and the hc path has its own
  tests and spikes.
- **A sync while the app runs:** folder swaps are atomic. A settings change
  made in the same second as a merge can be lost, and our declared keys
  win by design.
- **razer** builds through p620. `glab` / `gh` must be logged in on each
  machine where a space runs.

## Verification

On p620, then razer, after an announced deploy:

1. **Build:**
   - `just check-syntax`, `just test-host p620`, `just test-host razer`.
   - `herdr-team-test.sh` and `herdr-run-test.sh` pass with the TUI and
     hc cases.
   - The `herdr-claude-teams` build runs its tests.
   - A test for `herdr-app-sync` (a scratch app home) covers all four table
     rows, a failed `check` keeping the old mod, invalid JSON left alone, and
     a rerun that changes nothing.
2. **Sync on the host:**
   - With the app open, the switch installs the managed mods, the
     `freund` layout and the merged JSON. `herdr-app status` shows no errors,
     and the window switches to `freund` once.
   - Undeclared settings and keys are kept.
   - A hand edit ends up in `backups/`.
   - On a scratch `HERDR_APP_HOME`, the first launch converges.
3. **Mods:**
   - Inbox:
     - rows from all four provider/kind pairs, de-duplicated;
     - the cap banner;
     - Open;
     - Start agent, with and without a local clone;
     - the GitLab error line with `glab` logged out, while GitHub still
       works.
   - The issues panel on this repo; the gitlab panel on a gitlab.com repo.
   - A blocked agent makes a desktop notification, and clicking it focuses
     that agent.
4. **Keys:**
   - ctrl+hjkl between app panes, through Neovim splits and out at the
     edge; inside a Neovim terminal buffer and a picker, the key stays in
     Neovim.
   - alt+hjkl resizes Neovim splits inside Neovim and app panes elsewhere.
   - ctrl-shift-g, y, u and i do their actions.
   - No visible lag.
5. **Agents:** `freund-agents` shows:
   - Claude, Codex and agy on p620, and one on razer;
   - every control on them, including answering agy's trust prompt through
     Peek;
   - a Claude with Task subagents showing the count while working, and a
     Graph that opens zoe on the right machine.
6. **Teams, from an app terminal:**
   - `herdr-team up <task> review` → `ask` → `converse` → `finish` → `down`:
     members show under the lead in the team tab, and nothing is left
     running.
   - Killing the lead lets the watchdog clean up.
   - `herdr-run` shows a row and returns the exit status and stderr, and
     cancellation works.
   - A Claude agent team shows teammates as tabs after the lead; teardown
     touches only its own.
7. **hc:**
   - Versions 0.1.21 / 0.1.16; Updates says managed.
   - One `hc-hold-*` unit per terminal.
   - After `hc server restart`, the screen is restored.
8. **TUI unchanged:** `herdr` with all 13 plugins; `herdr-team` and
   `herdr-run` inside the TUI behave as before.
