---
status: draft
issue: 2859
spec: spec/2026-11-11-2859-hc-herdr-team-spike.md
# coders: none. No step edits repo files. The spike script lives in the
#   scratch directory, and running it and its live checks stay with the lead.
reviewers:
  - codex    # read the spike script before it runs (isolation, cleanup)
  - agy      # second read of the script; found the holder-core risk class
---

# Plan: spike — one Codex review through an isolated hc core

Self-contained summary of the approved decisions:

- **Scope:** Codex only, on p620 only. Results go in a comment on #2859.
  No repo, module, host change or deploy; the script is attached to the
  comment, not committed.
- **Isolation:** every `hc` call goes through `hcx`:

  ```bash
  spike=/tmp/claude-1000/hc-spike-2859
  hcx() {
    agent-env env -u HC_SOCKET HC_SESSION=spike2859 \
      XDG_CONFIG_HOME=$spike/config XDG_DATA_HOME=$spike/data \
      XDG_STATE_HOME=$spike/state XDG_CACHE_HOME=$spike/cache hc "$@"
  }
  ```

  Plain `hc` is never run: even `hc ls` starts the owner's core. Never stop
  or restart the owner's core.
- **Tokens:** the core and every Codex command start through `agent-env`.
  The Codex command also unsets the six API-key variables and sets
  `forced_login_method=chatgpt` and `--no-daemon`.
- **Read-only:** `git status --porcelain` is empty before and after, in the
  run worktree `../nixos-2859-run` (detached at `origin/main`). That
  worktree is kept until the end.

## Steps

1. **Write the script (lead)** at `$spike/../hc-spike-2859.sh`, outside
   `$spike` so cleanup doesn't delete it. It follows spec Design 1-3:
   - step 0: owner state, then `hcx server start` / `status`;
   - the isolation and environ checks, stopping if any fails;
   - the `spike-echo`, `spike-review`, `spike-scope`, `false` and untrusted
     templates;
   - run steps 1-12, then cleanup step 13.

   Every phase writes JSON or text to `$spike/out/<nn>-<name>`, and the
   script stops at the first failed isolation check. Check:
   `bash -n` and `shellcheck` on it.
   Traps:
   - `agent-env` keeps only an allowlist, so `HC_SESSION` must be set
     inside the `env` after it;
   - inside the holder terminal, repeat the full `hcx` environment prefix,
     and first check `hc server status` names `spike2859`;
   - `hc run` prints text unless `--json`;
   - `read` and `get` need a target ID.
2. **Review the script (lead, with `reviewers:`).** Codex and agy read the
   script and this plan read-only. Fix what holds up.
3. **Announce (lead).** Post on `#agents:freundcloud.org.uk`: an isolated
   `hc` core spike on p620, about 30 min, the owner's core untouched.
4. **Run step 0 only (lead).** Run the script up to the isolation check, and
   read `$spike/out/00-*`. If isolation fails: clean up, comment the
   finding on #2859, and stop here (the spike's answer is "can't isolate").
5. **Run the rest (lead).** Run steps 1-12 phase by phase, reading each
   output before the next. A phase that fails is recorded and the run goes
   on, unless it touches isolation.
6. **Clean up (lead).** Run step 13. Check that:
   - the owner's state matches step 0;
   - no process with `HC_SESSION=spike2859` is left;
   - `$spike` and `../nixos-2859-run` are gone.
7. **Report (lead).** Comment on #2859 with:
   - versions and the script (attached);
   - the comparison table;
   - the six "to find out" answers, marked verified or unverified;
   - the owner-state before/after;
   - the recommendation.

   Post the gotchas on the bus, save one memory file if something isn't
   obvious, then open a follow-up issue if the recommendation is to adopt.
   Close #2859.

## Tests

| Check | Expected |
|---|---|
| `bash -n`, `shellcheck` on the script | clean |
| step 0 isolation | new core, `HC_SESSION=spike2859`, no tokens, owner unchanged |
| `git status --porcelain` in `<run>`, before/after | empty |
| owner `pgrep -a herdr-core` + unit list, before/after | identical |
| leftover spike processes after cleanup | none |

## Rollback

Nothing in the repo or on hosts changes. Abort: `hcx server stop` (only
after `hcx server status` shows `spike2859`), kill any PID found with
`HC_SESSION=spike2859` in its environ, and remove `$spike` and
`../nixos-2859-run`.
