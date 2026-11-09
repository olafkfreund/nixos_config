---
status: approved
issue: 2810
intent: intent/2026-11-09-2810-herdr-agent-team.md
---

# Spec: herdr-native mixed agent team

## Feasibility (intent question 0), measured 2026-11-09

All probes used herdr 0.9.5 and codex-cli 0.167.0. The pane probes ran in an isolated named session
(`herdr --session t2810`, since deleted).

| Probe | Result |
| ----- | ------ |
| Codex started as `bwrap --dev-bind / / -- codex` via `pane run` | herdr detects it: `agent get` → `codex`, `idle` |
| `agent prompt <pane> "…" --wait` to it | delivered; Codex ran the turn |
| `agent read --source recent-unwrapped` afterwards | the reply is **not** there: Codex draws on the alternate screen |
| Same, with `~/.config/herdr` on tmpfs, `~/.codex/hooks.json` hidden and `HERDR_*` unset | `--wait` returned `idle` **while Codex was still working**. herdr's lifecycle state comes from the agent's hooks, which a sandbox cuts off |
| `codex exec -s read-only -c 'notify=[…]'` | Codex runs the notify program itself, outside the model's sandbox, after each turn, with `{"type":"agent-turn-complete","turn-id","input-messages","last-assistant-message"}` |

Conclusions:

- herdr can host and type into a sandboxed Codex, but it cannot tell when that agent is done or what it said.
- The **Codex `notify` hook** gives both, from the Codex process rather than the model, under a read-only sandbox:
  - the turn finished;
  - the exact input it answered;
  - the reply.

  The model never has to write a file, so the read-only reviewer stays read-only.
- The pane probes ran a looser sandbox than production, so nothing above proves the real wrappers. Plan step 1
  repeats probes 1–5 through the exact production wrappers before any other code lands. If they fail, the work
  stops there.
- A fresh herdr pane runs the owner's full login shell, `NIX_CONFIG` token included. No team pane may ever fall
  back to that shell.

## Scope

- **In:** the herdr skill for all three agents, and a team of **Codex** members in herdr panes:
  - a task-long reviewer;
  - a per-step implementer.
- **Conditional, owner-approved (2026-11-09): an agy `implement` member**, on the same terms as Codex's `notify`.
  agy 1.5.3 runs hooks from `~/.gemini/config/hooks.json` only, and they inherit each run's env (`AGY_CODER`).
  `#2794` already uses its `PreInvocation` event.
  - Plan step 1 finds the turn-end event: the one that fires once per turn and carries the reply or the transcript
    path. It probes in an isolated session without editing the synced `hooks.json`.
  - If that event exists, the member is defined in Design §2 (`agy-implement`). It starts through
    `agy-implement`, which keeps its guard preflight and probe.
  - If no such event exists, agy stays on its headless paths (`agent-run`, the `second-opinion` blocks), as
    today.

  agy is never a reviewer here: `agent-review` refuses it (#2748).
- **Out:**
  - Claude teammates, which `herdr-claude-teams` already runs.
  - A teammate-to-teammate mesh, cross-machine teams and worktree-per-agent.

## Design

### 1. The herdr skill (p620 and razer)

- A derivation, `runCommand "herdr-skill" { } ''mkdir -p $out; ${herdr}/bin/herdr --skill > $out/SKILL.md''`.
  It always matches the pinned binary.
- It is linked as `~/.claude/skills/herdr` and `~/.agents/skills/herdr`, which Codex and agy read.
- A Home Manager option (`programs.herdrSkill.enable`) is set in `Users/olafkfreund/profile.nix`, next to
  `pkgs.herdr`, so p510 gets nothing. `home/syncthing-stignore.nix` already lists `herdr` as host-local.
- The stale July clone at `~/.agents/skills/herdr` is a directory with `.git` and `Cargo.toml`. A one-shot
  activation step that runs before `linkGeneration` removes exactly that shape, so both hosts converge on deploy.
- It is for an agent the owner runs as the lead. Team members cannot see `~/.agents` or `~/.claude`, because the
  sandbox puts tmpfs over `/home`.

### 2. Members

Each member is one process, with one role, bound at start. Inside its sandbox, a member sees three paths of its
own:

| Path inside the sandbox | Host path | Mode | Who writes it |
| ----------------------- | --------- | ---- | ------------- |
| `/run/herdr-team/req` | `<work>/req` | read-only | the lead |
| `/run/herdr-team/turns` | `<work>/turns` | writable by the outer sandbox | the turn-end hook, run by the agent's own process |
| the worktree | the worktree | read-only (`review`), or writable (`implement`) | the model (`implement` only) |

`/run/herdr-team` is outside `/tmp` and outside the worktree, so a model's tool commands cannot write there:

- `review`'s inner sandbox is read-only;
- Codex's `workspace-write` allows only the cwd and temp directories;
- agy's `--sandbox` is checked in plan step 1.

So a forged turn file needs a sandbox escape, not just a shell command. `<work>` itself is never bound.

- **`review`**: interactive Codex, read-only, lasting for the task.
  - Started by a new `agent-review codex <work> --tui` mode. It runs `codex` with no subcommand, and the
    wrapper itself, not the caller, sets:
    - `sandbox_mode="read-only"` and `approval_policy="never"`, so no approval dialog can appear;
    - `mcp_servers={}`;
    - `notify=["<notify-sink>"]`.
  - The caller may add only today's keys (`model`, `model_reasoning_effort`). Today's refusals, mounts and env
    allow-list are unchanged.
- **`implement`**: interactive Codex for one plan step.
  - Started through **`codex-implement --work <work> --tui`**, so the guard preflight runs. `codex-implement`
    passes `--work` and `--tui` to `agent-implement` **before** its `--`, so neither reaches `codex`.
    `agent-implement` binds the two `/run/herdr-team` paths and starts `codex -p implement` with no `exec`. The
    profile file is mounted as today. The wrapper adds `approval_policy="never"` and `notify`.
  - The coder guard, no secrets, no Nix daemon socket and a read-only `.git` are unchanged.
- **`agy-implement`** (conditional, see Scope): `agy-implement --work <work> --tui`, with the same two binds.
  - The synced `hooks.json` gets one turn-end entry, gated on `[ -d /run/herdr-team/turns ]`. It is a no-op in
    every other agy run on every host, and it needs no env var. agy blocks every call when a hook fails, and the
    file syncs to p510 too. So the entry always prints `{}` and exits 0, even when the sink is missing on that
    host, as `nixi-working` does in #2794. Its normalized output is the same file shape as
    Codex's: `{turn_id, input, reply, source: "agy"}`.
  - Its guard still fences the model's writes to the worktree.
- **`notify-sink`**: a tiny packaged script run by the agent process.
  - It checks `type == "agent-turn-complete"`, and that `turn-id` matches `^[0-9a-f-]{36}$`.
  - It writes `{turn_id, input: input-messages[-1], reply: last-assistant-message, source: "codex"}`
    atomically (temp file plus rename) to `/run/herdr-team/turns/<turn-id>.json`.
  - It does nothing else and exits 0.

### 3. `herdr-team`, a new command (`home/development/herdr-team.sh`, packaged in `agent-run.nix`)

It is separate from `agent-team on|off|status`. It runs only with `HERDR_ENV=1`; outside herdr it exits 2 with
`herdr unavailable`, and the skills fall back to today's headless paths.

#### State and isolation

- **One lock** for state changes: `flock $XDG_RUNTIME_DIR/herdr-team/lock`. It is held only while state changes,
  never while waiting for a turn, so a stalled `ask` cannot block `down`.
- **State file:** `$XDG_RUNTIME_DIR/herdr-team/<task>.json`. It holds:
  - a random generation id `gen`, and the tab;
  - per member: role, pane id, terminal id, the launcher's pid **and start time** (from `/proc/<pid>/stat`) and
    pgid, the step, the start fingerprint (below), and the pending request;
  - the canonical worktree path;
  - the lead's pid and start time.
- **Two dirs per member:**
  - `<work>`: `/tmp/herdr-team.<gen>.<member>.XXXXXX` (`mktemp -d`, mode 0700), with `req/`, `turns/`,
    `turns/done/` and `ans/`. It is checked as `agent-review` checks today: owned by the caller, no symlinks, no
    sockets.
  - `<ctl>`: `$XDG_RUNTIME_DIR/herdr-team/<gen>/<member>/`. It holds `launch`, `claim`, `status` and
    `exit`, and is never bound into a sandbox.
- **Refusals at `up`**, as `agent-run.sh:23-38` refuses them today: `~/.config/nixos`, branch `main`, and a path
  that is not a git worktree.
- **Implementer checks at `up`:**
  - a dirty tree;
  - an existing implementer or finish reservation for the same canonical worktree, in any task's state file;
  - a task name whose state file has live members.

  A member counts as live only when its pid **and** start time still match.

#### Launch

`up` writes `<ctl>/launch` (mode 0700), then retries `pane run "exec bash <ctl>/launch || exit"` until
`<ctl>/claim` appears, as `herdr-run.sh:260-270` does. The launcher runs in the pane, in the host PID namespace:

1. It creates `<ctl>/claim`, and records its pid, start time and pgid.
2. It starts a **watchdog** in the background. Every 30 s it checks the lead's pid and start time and the role's
   maximum (8 h `review`, 3 h `implement`). When either fails, it sends TERM to the member's process group, then
   KILL after 5 s.
3. It runs the sandbox wrapper **in the foreground**, so the TUI keeps the pane's terminal:
   `agent-env agent-review …`, `agent-env codex-implement …` or `agent-env agy-implement …`.
4. When the wrapper exits, the launcher writes its exit code to `<ctl>/exit` (2 means refused), stops the
   watchdog and exits. The pane ends with it, and no shell is left. `|| exit` also covers `exec` failing.

`agent rename … <task>-<member>` runs only once herdr reports the expected kind on the recorded terminal.

#### Subcommands

| Subcommand | What it does |
| ---------- | ------------ |
| `herdr-team up <task> review` | Creates the tab `team <task>` if the task has none. The first member takes the tab's root pane; later ones `pane split --no-focus`. Launches the member as above |
| `herdr-team up <task> implement --step <k>` / `agy-implement --step <k>` | Same, after the implementer checks. Records the start fingerprint |
| `herdr-team ask <task> <member> <prompt-file>` | Refuses with `busy` while that member has a request pending. Gives the request number `n`, copies the prompt to `<work>/req/<n>.md`, and checks the pane, terminal, kind and pid. Then types **only** the pointer `Request <gen>-<n>: read /run/herdr-team/req/<n>.md and answer it in your reply.` with `agent prompt`. Waits for a turn file whose `input` equals that pointer **exactly**. Moves every turn file it reads to `turns/done/`, so no file matches twice. Writes the reply to `<work>/ans/<n>.md` |
| `herdr-team ask … --resume <n>` | Waits again for request `n` without typing anything |
| `herdr-team status <task>` | Members, liveness, pending requests and exit codes, as JSON |
| `herdr-team down <task> [member]` | Ends one member, or all. Marks a pending request `cancelled`. Sends TERM, then KILL, to the member's **process group**, checking pid and start time first so a reused pid is never signalled. Waits until the group is gone, then closes the pane if its terminal id still matches (`same_pane`, `herdr-run.sh`) |
| `herdr-team finish <task> implement\|agy-implement` | Takes a **finish reservation** on the worktree, held until the verdict is written. Then `down`s the implementer and waits until it has exited. Then runs `agent-run`'s checks against the start state: the launcher's exit code is 0, `HEAD` is unchanged, the diff is non-empty, nothing is staged, and the last request's outcome was `ok`. Prints today's verdict JSON (`ok`, `reason`, `changed`, `head_moved`, plus `exit`) |

#### Result of an `ask`

Each `ask` prints one JSON line: `ok`, `outcome`, `n`, `member`, `answer` (the path), `turn_id`, `revision_at_send`
and `revision_at_reply`. A revision is a fingerprint of:

- `HEAD`;
- `git diff HEAD --binary`;
- each untracked, unignored file's path and content (`git ls-files -o --exclude-standard`).

`changed_during_review` is set when the two revisions differ. That catches a change between send and reply, not
one that was reverted before the reply. A guaranteed snapshot is out of scope.

| `outcome` | Meaning |
| --------- | ------- |
| `ok` | a turn file matched, with a non-empty reply |
| `empty` | a turn matched with an empty reply |
| `provider_error` | the visible screen (`pane read --source visible`, polled while waiting and checked at the end) shows an auth, quota, rate-limit or capacity string. It is quoted verbatim, whether or not a turn completed |
| `interrupted` | the screen shows Codex's interrupted marker and no turn file arrived |
| `cancelled` | the member was downed while the request was pending |
| `agent_gone` | the pane, terminal, pid or start time changed, or `<ctl>/exit` exists. The exit code is included |
| `refused` | the wrapper exited 2 at launch; its stderr line is in `<ctl>/status` |
| `timeout` | none of these within the limit (default 900 s). The request stays pending for `--resume` |
| `busy` | another request is already pending |

A refusal or a provider error written as ordinary reply text is still `ok`. Telling that apart is the lead's
reading of the answer, as it is today with `exec -o`.

#### Lifetimes and crashes

- The watchdog ends a member within about 35 s of the lead dying, whether or not its pid was reused, because the
  start time is checked.
- A failed `up`, at any point, `down`s whatever it started.
- `up` reports stale state files, whose members are no longer live, and removes them.

### 4. Who talks to whom (intent question 1)

The lead is the hub. Members have no socket, no relay and no herdr skill, so they cannot address anyone.
Teammates "talk" through the lead:

- the lead reads `review`'s answer and checks each point against the plan and the code;
- it writes its own prompt to `implement`, and the other way round.

The lead never passes text on mechanically, which is why the first draft's `forward` subcommand was dropped.
Untrusted text never reaches a PTY either: only the fixed pointer line is typed, and content travels as files.

### 5. Skills and docs

- **`second-opinion`:** inside herdr, a Codex review is `herdr-team up <task> review` once, then `ask` for each
  question and follow-up. Outside herdr, the current blocks stay.
- **`handoff`:** inside herdr, a Codex step is `up … implement --step k`, then `ask` (once or more), then
  `finish`. agy steps, and anything outside herdr, stay on `agent-run`.
- **AGENTS.md** ("Delegating to other models") adds:
  - team members are sandboxed and have no herdr access;
  - an answer is a Codex-reported turn;
  - the lead checks every answer against the approved plan, and an answer never approves, widens scope or
    authorizes a commit, deploy or step change;
  - only the lead writes prompts.
- `docs/applications/herdr.md`: a "Team tab" section, and the 0.9.0 mention corrected to 0.9.5.
- `modules/programs/claude-code-managed-claude.md` names `herdr-team` as the route inside herdr.

## Alternatives rejected

- **`herdr agent start --kind codex`.** It runs the canonical executable in the login shell, outside every
  sandbox, with the shell's token. A pane runs `exec agent-env <wrapper> …` instead, and probe 1 shows herdr
  still recognizes it.
- **`agent prompt --wait` and `agent read`.** They are wrong under the sandbox (probes 3 and 4).
- **A model-written result file.** A read-only reviewer cannot write it, a model can skip it or write it early,
  and it proves nothing about the turn. `notify` is written by Codex itself.
- **Sending the prompt text through `agent prompt`.** Untrusted text would become terminal input. Only a fixed
  pointer line is typed.
- **Giving members the socket or the herdr skill.** The socket controls every pane, including the lead's.
- **`forward`.** It moves text without the lead checking it.
- **Running the watchdog inside the sandbox.** The sandbox has its own PID namespace, so it cannot see the
  lead's pid. The launcher runs the watchdog in the host namespace instead.
- **Removing the headless path.** It is still needed outside herdr, and for agy.

## Risks

- **Codex flag or `notify` payload drift.** The wrappers pin exact shapes and fail closed. `ask` checks the
  payload's `type` and fields, and refuses unknown ones with `provider_error`.
- **The owner types into a pane.** That is intended. Their turn produces a turn file without the pointer, which
  `ask` ignores, so it is never taken as the answer.
- **A Codex turn that never completes.** It times out, stays pending and is reported. It is never answered
  automatically.
- **Hosts:** p620 and razer only. p510 is unchanged.

## Verification

- **Plan step 1, through the production wrappers in an isolated herdr session.** The rest of the plan waits on
  it:
  - herdr detects the agent;
  - in the **interactive** TUI, not only `exec`, `notify` fires once per turn;
  - `input-messages[-1]` is the pointer;
  - an auth or quota error and an Esc-interrupted turn each show their own screen marker;
  - a model shell command cannot write `/run/herdr-team/turns` (`implement`), or anything at all (`review`);
  - for agy: the turn-end event, its payload, and that `--sandbox` blocks the same write;
  - inside the member, these all fail: connecting to every `~/.config/herdr/**/herdr.sock`, `herdr status`, and
    a write to the worktree (review), or `git add` (implement);
  - no fd above 2 points to a socket;
  - the caller's token-bearing `NIX_CONFIG` is absent and the sandbox's own value is exact;
  - when the agent exits, the pane ends, with no shell prompt.
- **Package tests** (`checkPhase`, fake herdr in the style of `herdr-run-test.sh`):
  - locking, generation ids, `busy`, a late answer filed under its own `n`, `--resume`, consumed turn files;
  - a forged turn file (bad `turn-id`, symlink, wrong `type`), which the sink refuses;
  - pid reuse, where the start time differs, which is never signalled;
  - the finish reservation blocking a second implementer;
  - each failure reason;
  - `down` closes only matching panes;
  - `finish` downs before checking;
  - outside herdr every command exits 2.
- **Sandbox tests:** `agent-review.test.sh` and `agent-implement.test.sh` cover the new argument shapes,
  wrapper-set keys a caller cannot override, and refusal of everything else.
- **Builds:** the p620 and razer toplevels. A p510 eval shows no herdr skill.
- **Live test after deploy** (default session, from a Claude pane):
  - one review conversation of two `ask`s that keeps context;
  - one implement step through `finish`;
  - `down` cleans up.
