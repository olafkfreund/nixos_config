---
status: approved
issue: 2859
intent: intent/2026-11-11-2859-hc-herdr-team-spike.md
---

# Spec: spike — one Codex review through an isolated hc core

Approved intent decisions:

- Codex only, on p620 only;
- results as a comment on #2859, no `docs/` page;
- an isolated core, never the owner's;
- the core and the Codex terminal have no tokens; Codex runs with
  `--no-daemon`;
- no change to herdr-team, modules or hosts, and no deploy.

## Design

### 1. Isolated core, checked before any terminal exists

Every `hc` call in the spike goes through one shell function. It starts
through `agent-env`, which keeps only an allowlist of variables (PATH, HOME,
LANG, TERM, XDG_*, USER, …), so the core starts without tokens:

```bash
spike=/tmp/claude-1000/hc-spike-2859
hcx() {
  agent-env env -u HC_SOCKET HC_SESSION=spike2859 \
    XDG_CONFIG_HOME=$spike/config XDG_DATA_HOME=$spike/data \
    XDG_STATE_HOME=$spike/state XDG_CACHE_HOME=$spike/cache hc "$@"
}
```

- `HOME` and `XDG_RUNTIME_DIR` stay: Codex needs `~/.codex`, and
  `systemd-run --user` needs the user bus. Any inherited `HC_SOCKET` is
  unset, so it can't point at the owner's core.
- **Step 0, before any terminal:**
  1. Record the owner's state: `systemctl --user list-units --all 'herdr*'
     'hc*'` and `pgrep -a herdr-core`. Plain `hc` is never called, because
     even `hc ls` would start the owner's core.
  2. `hcx server start`, then `hcx server status --json`.
  3. Check that a new `herdr-core` process exists, that its
     `/proc/<pid>/environ` has `HC_SESSION=spike2859`, no `NIX_CONFIG`
     access token and none of the API-key variables, and that its socket is
     not the owner's (from `server status`, or `ss -xlp`).
  4. Check that the owner's units and processes are unchanged.
  5. **If any check fails, stop** with `hcx server stop`, only if it reported
     the spike session; otherwise kill the new PID found in step 3. That
     failure is the spike's first finding.
- Every later `hcx` call targets this verified core. The spike script exits
  if the core's PID changes unexpectedly (it is re-read after the restart in
  step 7).

### 2. The review template

`$spike/config/herdr-core/templates/spike-review.md`, with frontmatter
`name`, `description` and `command` (the `hc --skill` format). The command
is herdr-team's `review` argv (`home/development/herdr-team.sh:428-429`)
plus `--no-daemon`:

```yaml
command: >-
  agent-env env -u OPENAI_API_KEY -u OPENAI_API_KEY_FILE -u GEMINI_API_KEY
  -u GEMINI_API_KEY_FILE -u GOOGLE_API_KEY -u ANTHROPIC_API_KEY
  -u ANTHROPIC_API_KEY_FILE codex --no-daemon
  --dangerously-bypass-approvals-and-sandbox -c forced_login_method=chatgpt
  -c 'notify=["<sink>","<spike>/turns"]'
  -c 'projects={"<run worktree>"={trust_level="trusted"},"<repo>"={trust_level="trusted"}}'
```

- The command itself starts with `agent-env` too, because `hc` gives
  programs the login session's environment, not only the core's.
- How `hc` splits `command` is not documented. Before the review, a
  `spike-echo` template with the same quoting (`printf '%s\n' …` with the
  two `-c` values) runs and shows the exact arguments. If the quotes don't
  survive, adjust them, then go on. `hcx templates --json` must list both
  templates.
- `<sink>` is the herdr-team sink store path, so its turn file can be
  compared with what `hc` returns. Both trust entries are needed for a
  linked worktree (herdr-team.sh:422-425).
- The body says: read-only review, no subagents, do not modify anything.

### 3. The run

One scratch worktree is used for both sides and kept until the very end:
`git worktree add ../nixos-2859-run --detach origin/main`.

1. `git status --porcelain` (expected empty).
2. **Review:**
   `hcx run --bg --json --name spike-review --cwd <run> spike-review "<prompt>"`.
   The prompt is a small fixed review: "review
   `home/development/herdr-team.sh` lines 570-590 for bugs, report findings
   ranked by severity". Record the terminal ID and `first_message.sent`. If
   it is false, `hcx read <id>` and record why before going on.
3. **Waiting:** a loop of `hcx wait <id> --timeout 60 --json`, at most 15
   times. Each round, record the status and whether a turn file appeared in
   `$spike/turns`. This shows whether Codex reports OSC 7501, or whether
   `wait` only ends on exit, without a 15-minute block.
4. **The answer, three ways:** `hcx read <id> --lines 400`, the turn file,
   and `hcx get <id> --json`. Compare completeness, duplicates and screen
   chrome.
5. **Environment:** check `/proc/<codex pid>/environ` the same way as the
   core's.
6. **Lead outside `hc`** (this Claude pane, no `$HC_TERMINAL_ID`):
   - record the review terminal's `parent` in `hcx get`;
   - `hcx wait --children all --timeout 5` and record what it says;
   - start a holder, `hcx run --bg --json --name spike-holder bash`. Inside
     it, every command repeats the `hcx` environment prefix explicitly. The
     holder may not inherit `HC_SESSION`, and a bare `hc` there could reach
     the owner's core. First check that `hc server status --json` from inside
     names the spike session; if not, skip this item and record why. Then
     start a child, `hc run --bg --name spike-child sleep 600`. Kill the
     holder and check that the child ends (lead-death cleanup through a
     holder).
7. **Restart:** `hcx server restart`. Check the review terminal survives.
   Record the new core PID and its environ, then start a new terminal
   (`hcx run --bg --json --name spike-post bash`) and check its environ.
8. **Failure cases**, each in a new terminal:
   - an early exit (a template whose command is `false`);
   - a timeout (`hcx wait --timeout 5` on a `sleep 60` terminal);
   - a trust dialog: the `spike-review` template without the `projects` trust
     entry, run in a new untrusted scratch directory
     (`mktemp -d -p $spike`). Record the status (`blocked`?), and the
     screen and `first_message.sent`, then kill it.
9. **Containment:** a `spike-scope` template that wraps the command in
   `systemd-run --user --scope --quiet --collect -- …` (like herdr-team:516),
   running `bash -c 'sleep 30'`. Check that `hc` still shows the terminal's
   status and exit code, and that the scope unit ends with it. The
   `codex-implement` guard preflight inside a template is **not** run: it
   is an implementer, and the intent is read-only. That stays unverified.
10. **Naming:** `hcx run --bg --json --name 2859 sleep 5` and `--name t2859`.
    Record whether each is accepted, and what `hcx get t2859` resolves to
    when a terminal ID like `t2859` could exist.
11. **The herdr-team side** (works before #2863 lands, since `t2859` starts
    with a letter): `herdr-team up t2859 review` in `<run>`, `ask` with the
    same prompt, then `down`. Record setup, retrieval and cleanup the same
    way.
12. `git status --porcelain` in `<run>` (expected empty).
13. **Cleanup:**
    - `hcx kill` and `hcx rm` each spike terminal;
    - `hcx server stop`, after `hcx server status` still shows the spike
      session;
    - list the spike core's process tree (recorded in step 0 and after step 7)
      and check that none of those PIDs, nor any process with `HC_SESSION=spike2859`
      in its environ, is left; kill leftovers by PID;
    - then remove `<run>` and `$spike`;
    - re-record the owner's state, which must match step 0.

### 4. Report

A comment on #2859 with:

- versions (`hc`, Codex, herdr);
- the spike script (attached, not committed);
- a comparison table (setup, answer, status, failures, cleanup, our lines
  of code);
- answers to the six "to find out" questions, each marked verified or
  unverified;
- a recommendation limited to what was shown.

## Alternatives rejected

- **Using the owner's core:** forbidden by the `hc` manual and the intent.
- **Only the template strips tokens:** the intent requires the core itself
  to start clean too, and a dirty core would make the environ check
  meaningless.
- **One long `hc wait --timeout 900`:** it blocks for 15 minutes if Codex
  reports no status.
- **Running `codex-implement` in a template:** it writes; the intent is
  read-only.
- **A `docs/` page; agy or Claude Code runs:** rejected at the intent gate.

## Risks

- **Isolation might not hold.** Step 0 checks it before any terminal exists,
  and stops the spike if it fails.
- **A changed `XDG_CONFIG_HOME`** hides the owner's git and other configs
  from `hc` and its children. Codex keeps `HOME`. If it misbehaves, that is
  recorded, not worked around.
- **Detached processes** may survive `hcx kill`. The cleanup checks the
  spike core's process tree and the `HC_SESSION` marker.
- **Token use:** two short Codex reviews on the subscription.

## Verification

- The comment on #2859 holds every item in Design 4.
- The owner's `hc` state is identical before and after (`pgrep -a
  herdr-core` and the unit list, both shown in the comment).
- `git status --porcelain` in `<run>` is empty before and after both runs.
- No process from the spike is left, and `$spike` and `<run>` are gone.

## Review notes

Reviewed read-only by Codex (gpt-6.1-sol) and agy (model not reported)
against `hc --skill` and the `hc` help. Both found:

- the core started without `agent-env`, against the intent;
- isolation was checked only after the first terminal;
- `read` and `get` were missing their target.

They also added:

- the missing method for trust dialogs, lead death, scope, naming and
  restart;
- the cleanup order.

agy also added `--json` on `run`, template quoting, both trust entries, the
900 s wait, and a single run worktree. Isolation itself stays unverified
until step 0. Advice only, not approval.
