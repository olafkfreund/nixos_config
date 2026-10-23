---
status: approved
issue: 2452
spec: spec/2026-10-23-2452-agy-guard-file-tools.md
---

# Plan: agy coder guard denies agy 1.4.5's file tools

agy 1.4.5 edits files with `write_file` (args `Path`, `Content`, `Overwrite`,
`Append`) and `edit_file` (args `Path`, `Target`, `Replacement`). The coder
guard allows only `write_to_file | replace_file_content |
multi_replace_file_content` and reads `TargetFile`, so `agy-implement` cannot
edit anything.

Approved decisions:

- Add the two new names to the existing write case and read
  `Path // TargetFile`.
- Keep the old names.
- Keep the guard an explicit allowlist. Do not touch the read-only allowlist
  unless the live probe (step 6) shows a read tool is denied; if it is, add
  the new name as a plan deviation.
- Fix the already-failing test baseline (no `AGY_WORKTREE`), then add the
  spec's seven cases.
- Update the handoff skill probe.
- Deploy p620 and razer only. p510 waits for its next deploy, and the PR says
  so.

All work happens in the worktree `~/.config/nixos-2452`, branch
`fix/2452-agy-guard-file-tools`.

## Steps

1. `modules/programs/agy-guard-adapter.sh:50-53`: extend the case label to
   `write_to_file | replace_file_content | multi_replace_file_content |
   write_file | edit_file)`. Change the jq to
   `.toolCall.args | (.Path // .TargetFile // empty) | sub("^file://"; "")`,
   and the deny message to `"$name without a path"`. Update the comment above
   the case if it names only the old tools. Verify by running step 2's tests.
   Traps: keep `@jq@` and `@realpath@` placeholders, because
   `claude-code-managed.nix:322-326` substitutes them. The `.gemini` scan
   above the case already covers `Path`. Leave it alone.

2. `modules/programs/agy-guard-adapter.test.sh`:
   - In `t()` (line 26), and in the two direct adapter calls at lines 73 and
     82, run with `env AGY_CODER="$1" AGY_WORKTREE=/tmp/wt`.
   - Change line 67's target to `/tmp/wt/a`.
   - Add the cases below next to line 67. Verify with the command after the
     table, which must print `agy guard adapter: all cases pass` and exit 0.
     Before the change it fails on line 67.

   | tool | args | want |
   | --- | --- | --- |
   | `write_file` | `Path:"/tmp/wt/a",Content:"x"` | allow |
   | `edit_file` | `Path:"/tmp/wt/a",Target:"x",Replacement:"y"` | allow |
   | `write_file` | `Path:"/tmp/elsewhere/a",Content:"x"` | deny |
   | `edit_file` | `Path:"/tmp/wt/../elsewhere/a",Target:"x",Replacement:"y"` | deny |
   | `write_file` | `Content:"x"` | deny |
   | `write_file` | `Path:"/tmp/wt/.gemini/x",Content:"x"` | deny |

   ```bash
   bash modules/programs/agy-guard-adapter.test.sh
   ```

   Traps: `realpath -m` does not need `/tmp/wt` to exist. Do not create it.

3. `home/development/claude-code-skills/handoff/SKILL.md:62-70` ("After an
   agy update"):
   - Replace "edit a file with `write_to_file`" with "edit a file with
     `edit_file`".
   - Replace "`write_to_file` to a path outside the repo" with "`write_file`
     to a path outside the repo".
   - Add a first sentence: "Run `bash modules/programs/agy-guard-adapter.test.sh`
     first; it must pass."

   Verify that markdownlint passes in the pre-commit hook.
   Traps: markdownlint lints the whole file, so fix any pre-existing lint
   error it reports in that file.

4. Build both hosts and confirm the new guard is in the closure. Verify with:

   ```bash
   just test-host p620 && just test-host razer
   grep -c write_file result/etc/antigravity/hooks/coder-guard
   ```

   The `grep` (run on a host build's `result` symlink, or on the `/etc` path
   after the deploy) must return 1 or more. Then commit steps 1-3 as
   `fix(agy): allow agy 1.4.5 write_file/edit_file in coder guard (#2452)`
   and push.

   Traps:
   - Pipe nothing into `tail` without `set -o pipefail`.
   - Never build p510.

5. Deploy p620, then razer:
   - Before each deploy, `read_new("#agents:freundcloud.org.uk")`, `post` the
     plan, and run with `AGENT_BUS_ANNOUNCED=1`.
   - The deploy recipes refuse a non-main branch, so set
     `ALLOW_BRANCH_DEPLOY=1`. Merge `origin/main` into the branch first, so the
     deploy does not roll back main's newer commits.
   - p620: `just quick-deploy p620`.
   - razer: `just deploy-via-p620 razer`.

   Verify on each host that `/etc/antigravity/hooks/coder-guard` contains
   `write_file`.

   Traps:
   - razer `switch` may exit 4 from Syncthing. That is cosmetic, so check
     `systemctl --failed`.
   - Check that no `nhs` is running in `~/.config/nixos` first.

6. Live probe on p620 and on razer (`ssh razer`). In a fresh scratch git repo,
   run `agy-implement --output-format json --print-timeout 5m -p ...` four
   times:

   | Ask agy to | Expected result |
   | --- | --- |
   | append `world` to `a.txt` | file changed, `status` is `SUCCESS` |
   | read `a.txt` and quote it | content quoted (read tool not denied) |
   | write `/tmp/agy-probe-outside` | denied, file absent |
   | run `git commit -am x` | denied, `HEAD` unchanged |

   Fail the probe if any row differs. If a read tool is denied, add its name
   to the read allowlist in step 1's file as a plan deviation, with a test
   case, then repeat steps 4-6.

7. Open the PR. It must:
   - link the intent, spec and plan
   - say which steps the `coder` agent did
   - include the probe results per host
   - note that p510 gets the fix at its next deploy

## Tests

- `bash modules/programs/agy-guard-adapter.test.sh` prints
  `all cases pass` and exits 0.
- `just test-host p620` and `just test-host razer` succeed.
- The step 6 probe table matches on both hosts.

## Rollback

`git revert` the fix commit and redeploy p620 and razer. The guard returns to
denying all agy edits, which is today's fail-closed state, so a rollback is
always safe.

## Execution

Steps 1-3 edit three files, so under the model split they go to the `coder`
agent (step 1 first, then steps 2 and 3 through `SendMessage`). An Opus agent
reviews the diff against this plan. I run steps 4-7 myself (build, deploy,
probe, PR).
