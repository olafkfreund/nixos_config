---
status: approved
issue: 2452
intent: intent/2026-10-23-2452-agy-guard-file-tools.md
---

# Spec: agy coder guard denies agy 1.4.5's file tools

## Design

### 1. Guard: accept the new tool names and argument

In `modules/programs/agy-guard-adapter.sh`, the write case (currently lines
50-61) gains `write_file | edit_file`, and the target becomes
`Path // TargetFile`:

```bash
  write_to_file | replace_file_content | multi_replace_file_content | write_file | edit_file)
    ...
    target="$(echo "$payload" | @jq@ -r '.toolCall.args | (.Path // .TargetFile // empty) | sub("^file://"; "")')"
    [ -n "$target" ] || deny "$name without a path"
```

Everything else in the case stays: the `AGY_WORKTREE` fence, `realpath -m`,
and the `~/.gemini` check that runs before the `case` and already scans every
string argument, so `Path` is covered. The old names stay allowed (approved
open question), so a host still on an older agy keeps working.

The read-only allowlist (`view_file | grep_search | list_dir | find_by_name
| ...`) is not changed in this task. The scratch-repo run never reached a
read tool, so whether 1.4.5 renamed those is unverified. Step 3 below checks
it, and if a read tool is denied, the fix is added here as a plan deviation.

### 2. Tests: fix the baseline, then cover the new tools

`modules/programs/agy-guard-adapter.test.sh` fails on `main` today: its
`write_to_file` case predates the #2296 worktree fence and never sets
`AGY_WORKTREE`, so the adapter denies it. Fix: the `t` helper runs the
adapter with `AGY_WORKTREE=/tmp/wt`, and the write cases target paths under
it. New cases:

| Payload | Want |
| --- | --- |
| `write_file` `Path=/tmp/wt/a` | allow |
| `edit_file` `Path=/tmp/wt/a` | allow |
| `write_file` `Path=/tmp/elsewhere/a` | deny |
| `edit_file` `Path=/tmp/wt/../elsewhere/a` | deny (realpath escape) |
| `write_file` with no `Path` | deny |
| `write_file` `Path=/tmp/wt/.gemini/x` | deny |
| `write_to_file` `TargetFile=/tmp/wt/a` | allow (old name kept) |

### 3. Handoff skill probe

In `home/development/claude-code-skills/handoff/SKILL.md`, "After an agy
update", replace "edit a file with `write_to_file`" and "`write_to_file` to a
path outside the repo" with `write_file`/`edit_file`. Also add one line: run
`bash modules/programs/agy-guard-adapter.test.sh` before the live probe.

### 4. Rollout

Build and deploy p620 (local), then razer (`just deploy-via-p620 razer`),
announcing each on the agent bus first. p510 is not deployed in this task
(approved open question); it picks the fix up at its next deploy, and the PR
says so. All agy sessions on a host share `/etc/antigravity/hooks/coder-guard`,
so one deploy per host covers every session there. No restart is needed: agy
runs the hook fresh on each tool call.

Out of scope, as a separate issue (approved open question): letting Claude
dispatch Codex and agy without being asked each time, and having
`update-antigravity` run the probe automatically.

## Alternatives rejected

- **Allow any tool whose args contain a path inside the worktree.** This is
  broader than needed and turns the allowlist into a denylist; a future
  command-running tool with a `Cwd` arg would pass. The guard stays an
  explicit allowlist.
- **Drop the old names.** Rejected by the approved open question: it costs
  nothing to keep them, and agy versions can differ between hosts.
- **Pin agy back to the previous version.** That hides the rename until the
  next bump and leaves the auto-updater fighting the pin.

## Risks

- **The fence weakens.** Mitigated by the escape, `.gemini` and missing-path
  test cases, and by the live probe on both hosts (write outside the repo must
  be denied, and `HEAD` must not move).
- **`edit_file` replaces every occurrence of `Target`.** That is agy's own
  semantics, not a guard concern: the diff is reviewed before commit, as with
  any handoff.
- **razer deploy.** This is a small closure change (one `/etc` script), with
  no NVIDIA or kernel bump expected, so `switch` should succeed. Razer
  sometimes returns exit 4 from Syncthing, which is cosmetic (known).

## Verification

1. `bash modules/programs/agy-guard-adapter.test.sh` prints
   `all cases pass` and exits 0.
2. `just test-host p620` and `just test-host razer` build.
3. After deploying each host, in a scratch git repo there:
   - `agy-implement` appends a line to a file, and the diff shows it.
   - It is asked to read a file (`view_file`), which must succeed.
   - It is asked to write outside the repo, which must be denied.
   - It is asked to run `git commit`, which must be denied, and `HEAD` must
     not move.
