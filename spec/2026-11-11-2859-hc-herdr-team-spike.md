---
status: draft
issue: 2859
intent: intent/2026-11-11-2859-hc-herdr-team-spike.md
---

# Spec: spike — one Codex review through an isolated hc core

Approved intent decisions:

- Codex only, on p620 only;
- results as a comment on #2859, no `docs/` page;
- an isolated core, never the owner's;
- no tokens in the Codex environment, and `--no-daemon`;
- no change to herdr-team, modules or hosts.

## Design

### 1. Isolated core

Every `hc` call in the spike runs with one environment prefix, set once in a
shell function in the spike script (`hcx`):

```bash
spike=/tmp/claude-1000/hc-spike-2859
hcx() {
  HC_SESSION=spike2859 XDG_CONFIG_HOME=$spike/config XDG_DATA_HOME=$spike/data \
    XDG_STATE_HOME=$spike/state XDG_CACHE_HOME=$spike/cache hc "$@"
}
```

- `HOME` and `XDG_RUNTIME_DIR` stay as they are: Codex needs `~/.codex`,
  and `systemd-run --user` needs the user bus.
- Before anything starts, record the owner's state:
  - `systemctl --user list-units --all 'herdr-core*' 'hc*'`;
  - `pgrep -a herdr-core`.
  
  Plain `hc` is never called, because even `hc ls` would start the owner's
  core.
- The first `hcx` call starts the spike core. The run checks that it is a
  new unit or process, and that the owner's list is unchanged. If the spike
  core is not separate, the spike stops there, and that is a finding.

### 2. The review template

`$spike/config/herdr-core/templates/spike-review.md`, frontmatter
`name`, `description`, `command`. The command is herdr-team's `review` argv
(`home/development/herdr-team.sh:428-429`) plus `--no-daemon`:

```text
agent-env env -u OPENAI_API_KEY … -u ANTHROPIC_API_KEY_FILE codex --no-daemon
  --dangerously-bypass-approvals-and-sandbox -c forced_login_method=chatgpt
  -c notify=["<herdr-team-sink>","<spike>/turns"] -c projects={…trusted…}
```

- The command itself starts with `agent-env`, so the Codex process drops the
  tokens even if the core's environment has them. The run checks
  `/proc/<codex pid>/environ` for `NIX_CONFIG` and the six API-key
  variables, and checks the core's own environ too, to answer the
  core-environment question.
- The `notify` sink is the store path herdr-team uses, so a turn file can be
  compared with what `hc` returns.
- The body says: read-only review, no subagents, do not modify anything.

### 3. The run

In a scratch worktree of this repo at `origin/main`
(`git worktree add ../nixos-2859-run --detach origin/main`):

1. `git status --porcelain` (expected empty).
2. `hcx run --bg --name spike-review --cwd <worktree> spike-review "<prompt>"`.
   The prompt is a small fixed review: "review
   `home/development/herdr-team.sh` lines 570-590 for bugs, report findings
   ranked by severity". Record `first_message.sent`.
3. `hcx wait spike-review --timeout 900`. Record each status it returns
   (does Codex report OSC 7501 at all?).
4. Get the answer three ways and compare: `hcx read --lines 400`, the
   `notify` turn file in `$spike/turns`, and `hcx get --json`.
5. Lead outside `hc`: from this Claude pane (no `$HC_TERMINAL_ID`), record
   what `hcx get` shows as the parent.
6. `hcx server restart` (the spike core only). Check that the terminal and
   its environment survive.
7. Failure cases:
   - an early exit (`hcx run` a template whose command is `false`);
   - a timeout (`hcx wait` with `--timeout 5` while it works).

   Record what each reports.
8. Cleanup:
   - `hcx kill` and `hcx rm` each terminal;
   - `hcx server stop`;
   - check that no `codex` process with that worktree as cwd is left
     (detached processes);
   - remove the worktree and `$spike`;
   - re-record the owner's state, which must match step 1.
9. `git status --porcelain` in the worktree before removal (expected empty).

### 4. The herdr-team side

After #2863 is deployed: `herdr-team up t2859 review`, `ask` with the same
prompt, `down`. Record setup steps, answer retrieval and cleanup the same
way.

### 5. Report

A comment on #2859 with:

- versions (`hc`, Codex, herdr);
- the exact commands;
- a comparison table (setup, answer, status, failures, cleanup, our lines
  of code);
- answers to the six "to find out" questions, each marked verified or
  unverified;
- a recommendation limited to what was shown.

The spike script itself is attached to the comment, not committed.

## Alternatives rejected

- **Using the owner's core:** forbidden by the `hc` manual and by the intent.
- **Starting the core under `agent-env` only:** on Linux, the core's
  environment comes from the login session (the manual: "Linux session …
  refreshes"), so the command must strip the tokens itself.
- **A `docs/` page:** rejected at the intent gate.
- **agy or Claude Code runs:** Codex only, as approved.

## Risks

- **The `HC_SESSION` isolation might not separate the systemd unit**, so the
  spike core and the owner's could collide. The step 1 check catches that
  before any agent starts.
- **A changed `XDG_CONFIG_HOME`** hides the owner's git and other configs
  from `hc` and its children. Codex keeps `HOME`; if it misbehaves, that is
  recorded, not worked around.
- **Detached Codex children** may survive `hc kill`. Step 8 looks for them
  and kills them by PID if found.
- **Token use:** one short Codex review on the subscription, plus one through
  herdr-team.

## Verification

- The comment on #2859 holds every item in Design 5.
- The owner's `hc` state before and after is identical. Run `pgrep -a
  herdr-core` and the unit list, and show both in the comment.
- `git status --porcelain` is empty before and after both runs.
- No `codex` or `herdr-core` process from the spike is left; `$spike` and the
  scratch worktree are gone.

## Review notes

(pending)
