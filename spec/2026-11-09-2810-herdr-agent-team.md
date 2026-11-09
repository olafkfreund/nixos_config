---
status: draft
issue: 2810
intent: intent/2026-11-09-2810-herdr-agent-team.md
---

# Spec: herdr-native mixed agent team

## Feasibility (intent question 0), measured 2026-11-09

These were run in an isolated named session (`herdr --session t2810`, since deleted) with herdr 0.9.5 and Codex
in this worktree:

| Probe | Result |
| ----- | ------ |
| Codex started as `bwrap --dev-bind / / -- codex` via `pane run` | herdr detects it: `agent get` → `codex`, `idle` |
| `agent prompt <pane> "…" --wait` to that Codex | delivered; Codex ran the turn |
| `agent read --source recent-unwrapped` afterwards | the reply is **not** in it: Codex draws on the alternate screen |
| Same, with `~/.config/herdr` on tmpfs, `~/.codex/hooks.json` hidden and `HERDR_*` unset, as in our sandbox | `--wait` returned `idle` **while Codex was still working**. herdr's lifecycle state comes from the agent's hooks, which the sandbox cuts off |
| Asking that Codex to write its answer to a file | the file appeared, with the answer, after the turn |

Conclusions:

- herdr can host and type into a sandboxed agent, but it cannot tell when that agent is done.
- Completion and the answer both come from a **result file** the teammate writes. The lead waits for that file,
  never for `--wait` or a screen read.
- Teammates cannot reach the herdr socket inside the sandbox, which is what the intent requires. They also have
  no herdr skill to use there, because the sandbox hides `~/.agents` and `~/.claude`.
- A fresh herdr pane runs the owner's full login shell, `NIX_CONFIG` token included. A teammate must start
  through `agent-env` and its sandbox wrapper, never as a plain command in that shell.

## Design

### 1. The herdr skill, declaratively (p620 and razer)

- Generate the skill from the pinned binary, `runCommand "herdr-skill" { } "herdr --skill > $out/SKILL.md"`, so
  it always matches the installed herdr.
- Install it as a Claude skill and in `~/.agents/skills/herdr`, which Codex and agy read.
- The stale July clone at `~/.agents/skills/herdr` is replaced. The plan removes it once by hand; Home Manager
  then owns the path.
- Gate it the way `pkgs.herdr` is gated (`Users/olafkfreund/profile.nix`), so p510 gets nothing.
  `home/syncthing-stignore.nix` already lists `herdr` as host-local.

It is for an agent the owner runs as the lead in a herdr pane. Sandboxed teammates never see it.

### 2. `herdr-team`, a new command (`home/development/herdr-team.sh`, packaged in `agent-run.nix`)

It is separate from `agent-team on|off|status`, which stays as it is. It runs only when `HERDR_ENV=1`; outside
herdr it exits 2 with `herdr unavailable`, and the skills fall back to today's headless path.

| Subcommand | What it does |
| ---------- | ------------ |
| `herdr-team up <task> <member>...` | Opens one tab `team <task>` in the caller's workspace (`tab create --no-focus`). Splits one pane per member. Each pane starts the member through its sandbox (below), then gets the agent name `<task>-<member>` (`agent rename`). Writes the state file `$XDG_RUNTIME_DIR/herdr-team/<task>.json`: tab, panes, terminal ids, members, the work dir and the lead's session. Refuses if that task already has live panes |
| `herdr-team ask <task> <member> <prompt-file>` | Gives the request a number `n`. Prepends a fixed footer: write the answer to `$work/<member>/<n>.md`, then write `$work/<member>/<n>.done`. Sends the prompt with `agent prompt` to the named agent, after checking that the pane still has the same terminal id and the expected agent kind. Waits for `.done`. Prints one JSON line: `ok`, `reason`, `answer` (path), `n`, `member` and `revision` (`git rev-parse HEAD` when sent) |
| `herdr-team forward <task> <from> <n> <to>` | The lead-gated lane. Sends `<from>`'s answer `n` to `<to>` as a new `ask`, wrapped as quoted data from `<task>-<from>` with a header saying it is untrusted. Used for reviewer → implementer and implementer → reviewer |
| `herdr-team down <task>` | Closes only panes in that task's state file whose terminal id still matches (the `same_pane` check from `herdr-run.sh`). Their sandboxes stop with them. Removes the state file |

`ask` reports `ok: false` with a reason for each failure:

- `timeout` (default 900 s);
- `agent_gone`: the agent exited, or the pane changed;
- `blocked`: the screen shows an approval dialog, which the owner answers in the pane;
- `provider_error`: an auth, quota or capacity string is on screen, quoted verbatim;
- `empty`: the answer file is empty.

On any failure it saves the last 60 screen lines to `$work/<member>/<n>.screen` for the lead to quote.

### 3. Members and their sandboxes

Each member is bound to one role at start, and a role never changes inside a process.

- **`codex-review`**: Codex, interactive, read-only.
  - `agent-review` gets an interactive mode: `agent-review codex <work> -- tui`. It runs `codex` with no
    subcommand, `--sandbox read-only`, and the same refusals, env allow-list and mounts it has today. The
    worktree is read-only, and `<work>` is the only writable path.
  - Codex's own approval prompts show in the pane for the owner to answer.
  - It lasts for the task, so a review can be a conversation.
- **`codex-implement`**: one process per plan step.
  - `herdr-team up <task> codex-implement --step <k>` starts it through `agent-implement codex -- -p implement`,
    the interactive form of today's `-p implement exec`. It keeps the coder guard, no secrets, no Nix daemon and
    a read-only `.git`. Only the task worktree and `<work>` are writable.
  - When the lead accepts the step, it runs today's `agent-run` checks against the worktree: a clean tree before,
    `HEAD` unchanged, a non-empty diff. Then `herdr-team down`. The next step starts a fresh process.
  - One implementer per worktree. `up` refuses a second one.
- **agy:** not a reviewer, since `agent-review` refuses agy (#2748) and the owner set agy aside.
  - It is an implementer only if plan step 1 proves interactive agy works under
    `agent-implement agy -- --mode accept-edits --sandbox --dangerously-skip-permissions`. The guard adds that
    last flag, as it does now.
  - If that fails, agy keeps the headless `agent-run` path. Answers intent question 4 conservatively; the owner
    can widen it.
- **Claude teammates:** out of scope. `herdr-claude-teams` already runs those.

### 4. Who talks to whom (intent question 1)

The lead is the hub. Teammates have no socket and no relay, so they cannot address anyone. "Talking to each
other" is `forward`: the lead decides, per message, to pass one teammate's answer to another, labelled with the
sender, as data. The reviewer → implementer lane the intent recommended is `forward`.

A direct mesh would need a relay daemon outside the sandbox, with a per-member socket in each work dir so the
caller is known. It is left for a follow-up issue, if the hub proves too slow in practice.

### 5. Skills and docs

- **`second-opinion`:** inside herdr, a Codex review is `herdr-team up <task> codex-review` once, then `ask`, and
  follow-ups go to the same pane. The pinned read-only guarantees are unchanged. Outside herdr, the current
  `herdr-run … agent-review …` blocks stay as they are.
- **`handoff`:** inside herdr, a step is `up … codex-implement --step k`, `ask` and the checks above. Outside
  herdr it stays `agent-run`.
- **AGENTS.md** ("Delegating to other models") gains three points:
  - team panes are sandboxed;
  - their answers are files;
  - only the lead forwards.
- `docs/applications/herdr.md`: a "team tab" section, and the 0.9.0 → 0.9.5 mention fixed.
- `claude-code-managed-claude.md` (the agent-team rules) names `herdr-team` as the inside-herdr route.

## Alternatives rejected

- **`herdr agent start --kind codex`.** It runs the canonical executable in the login shell, outside every
  sandbox, and the shell carries the GitHub token. Instead, a pane runs `agent-env agent-review|agent-implement …`.
  herdr still recognizes the agent (probe 1), and `agent rename` names it.
- **`agent prompt --wait` and `agent read` for results.** With the hooks cut off, herdr reports `idle` while the
  agent works, and the alternate screen hides the reply (probes 3 and 4). Result files are the only signal that
  is reliable.
- **Giving teammates the socket, or the herdr skill, for direct messages.** Anyone with the socket can type into
  the lead's pane and answer its permission prompts. A skill is not a boundary.
- **One pane per provider that switches between review and implement.** The mounts are fixed at start, so a
  switch would need a respawn anyway. Separate members are clearer, and authority stays bound to the role.
- **Removing the headless path.** It is still needed outside herdr, and over SSH without a herdr session.

## Risks

- **Codex's interactive flags drift.** `agent-review` and `agent-implement` pin exact argument shapes and refuse
  others. A Codex update that renames a flag makes `up` fail closed, which is safe but stops the team.
- **The model skips the result file.** The footer is fixed and `ask` times out. The `.screen` capture shows what
  happened, and nothing is treated as an answer without `.done`.
- **The owner types into a pane mid-request.** That is intended. `ask` only trusts the files, so a manual turn
  that writes no `.done` reads as a timeout, not an answer.
- **A lead crash leaves panes open.** They hold read-only or step-scoped sandboxes, with no socket and no secrets.
  `herdr-team down <task>` closes them, and `up` lists stale state files.
- **A Codex approval prompt in a pane blocks `ask`.** It is reported as `blocked` with the screen, and the owner
  answers it there. It is never auto-answered: herdr's `send-keys` is not used on an approval.
- **Hosts:** p620 and razer only. Nothing changes on p510.

## Verification

- **Package tests** (`checkPhase`, fake herdr in the style of `herdr-run-test.sh`):
  - `up` creates a tab and named panes and writes the state file;
  - `ask` writes the footer, numbers requests, and maps each failure to its reason;
  - `forward` quotes the answer as data with the sender;
  - `down` closes only matching panes;
  - outside herdr every command exits 2.
- **Sandbox tests:** `agent-review.test.sh` and `agent-implement.test.sh` cover the new interactive argument
  shapes and refuse everything else.
- **Live test**, in an isolated session as in the probes:
  - in the sandboxed member, `HERDR_SOCKET_PATH` is unset, `~/.config/herdr/herdr.sock` is absent, and
    `NIX_CONFIG` is unset;
  - `codex-review` refuses a write to the worktree;
  - `codex-implement` cannot `git add`;
  - one review conversation of two `ask`s keeps context;
  - one `forward` reaches the other member.
- **Builds:** `nix build` of the p620 and razer toplevels. A p510 `nix eval` shows no herdr skill.
- **Deploy:** p620 and razer, then the live test once in the default session from a Claude pane.
