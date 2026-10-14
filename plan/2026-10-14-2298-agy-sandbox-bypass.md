---
status: draft
issue: 2298
spec: spec/2026-10-14-2298-agy-sandbox-bypass.md
---

# Plan: agy-implement's sandbox holds, and agy cannot bypass it

Worktree `../nixos-2298`, branch `fix/2298-agy-sandbox-bypass`.

## Approved decisions (carried over from the spec)

- **Cause of the sandbox failure.** agy's sandbox (agy re-executed in user,
  mount and PID namespaces) remounts `/bin` with only
  `MS_RDONLY|MS_REMOUNT|MS_BIND`. envfs's FUSE mounts on `/bin` and
  `/usr/bin` carry `nosuid,nodev` by default. Those flags are locked in a
  user namespace, so the remount gets EPERM and the sandbox dies, which
  shows up as "connection reset". With `suid,dev` on both mounts, the
  sandbox starts (tested in a private namespace on p620).
- **Fix 1.** Add `suid` and `dev` to `fileSystems."/usr/bin".options` and
  `fileSystems."/bin".options` when `services.envfs.enable`. This is
  harmless, because envfs only serves symlinks.
- **Fix 2.** The agy guard adapter denies `run_command` with
  `BypassSandbox: true` (only under `AGY_CODER=1`).
- **Fix 3.** The handoff skill says terminal commands are read-only in the
  sandbox (agy mounts the workspace read-only), so edits go through agy's
  file tools. The after-update probe adds two checks: a sandboxed
  `git status` succeeds, and a bypass is denied.
- **Upstream.** File the remount bug with google-antigravity/antigravity-cli,
  but only after the user confirms, because it is outward-facing.
- **Rejected:** dropping `--sandbox` (the user chose option A), a per-run
  root namespace, disabling envfs, and making the workspace writable for
  commands.

## Steps

1. **`modules/programs/claude-code-managed.nix`, in the
   `config = lib.mkIf cfg.enable { ... }` block next to line 1008**
   (`environment.etc."antigravity/hooks/coder-guard"`):

   ```nix
   # agy's sandbox remounts /bin read-only without repeating envfs's FUSE
   # nosuid,nodev, which a user namespace locks -> EPERM (#2298). Harmless on
   # envfs: it serves symlinks, so suid/dev follow the target's mount.
   fileSystems = lib.mkIf config.services.envfs.enable {
     "/usr/bin".options = [ "suid" "dev" ];
     "/bin".options = [ "suid" "dev" ];
   };
   ```

   Verify:
   - `just check-syntax`.
   - For both `/bin` and `/usr/bin`,
     `nix eval --json .#nixosConfigurations.p620.config.fileSystems."/bin".options`
     includes `suid` and `dev` next to the envfs ones.
   - The p620 toplevel builds with `set -o pipefail`.

   Trap: the module function must have `config` in its arguments, so check
   that before using `config.services.envfs`.

2. **`modules/programs/agy-guard-adapter.sh:62-66`.** In the `run_command`
   branch, after the `CommandLine` check, add:

   ```sh
   if echo "$payload" | @jq@ -e '.toolCall.args.BypassSandbox == true' >/dev/null 2>&1; then
     deny "agy-implement may not bypass the sandbox (#2298)"
   fi
   ```

   Verify:
   - Build the p620 toplevel.
   - Run the built `/etc/antigravity/hooks/coder-guard` with `AGY_CODER=1`
     on three sample payloads:
     - a `run_command` with `BypassSandbox: true` is denied;
     - the same command with `false` or no field is allowed (for example
       `git status`);
     - `git commit` is still denied.
   - shellcheck on the built script.

   Trap: shfmt reformats this file in pre-commit. Re-stage and commit again
   if it changes it.

3. **`home/development/claude-code-skills/handoff/SKILL.md`.**
   - **"Prompt template":** add a bullet saying that shell commands run in
     agy's sandbox with the worktree read-only, so the step's edits must be
     made with agy's file tools, and commands are for checks only.
   - **"After an agy update":** extend the probe sentence to include a
     sandboxed `git status` (must succeed) and a `run_command` with
     `BypassSandbox: true` (must be blocked).

   Verify with `pre-commit run --files <SKILL.md>`, and again with
   `--hook-stage pre-push`.

   Trap: write "Issue #2298", never a line that starts with "#2298".

4. **Deploy p620 and verify.** Run the bus `recent` check, `post`, then
   `AGENT_BUS_ANNOUNCED=1 ALLOW_BRANCH_DEPLOY=1 just p620` from the worktree
   (rebase onto `origin/main` first if it moved), then post completion.
   - `grep -E ' /bin | /usr/bin ' /proc/self/mountinfo` shows no
     `nosuid,nodev`. If they are still there, the switch did not remount.
     Announce on the bus, then run
     `sudo mount -o remount,suid,dev /usr/bin && sudo mount -o remount,bind,suid,dev /bin`,
     and record that in the plan as a deviation.
   - Plain `agy --sandbox --dangerously-skip-permissions -p "run git status"`
     in a scratch repo under `/home` succeeds with no connection reset.
   - `agy-implement` probe in a scratch repo under `/home`. These must pass:
     - `write_to_file` inside the worktree is written;
     - `git commit` is blocked;
     - `touch ~/.gemini/x` is blocked;
     - `write_to_file` outside the worktree is blocked;
     - a sandboxed `git status` succeeds;
     - a `run_command` with `BypassSandbox: true` is denied with the new
       message;
     - `HEAD` is unchanged.

5. **Deploy razer and verify.** Run
   `just deploy-via-p620 razer` with the same announce and env, check its
   mountinfo, and run the same probe over ssh. p510 is not deployed.

6. **Upstream.** Draft the antigravity-cli issue text (the cause, the raw
   syscall reproduction, the expected behaviour) in the scratchpad, show it
   to the user, and file it only on their go-ahead.

## Tests

| Command | Expected |
| --- | --- |
| `just check-syntax` | passes |
| p620 and razer toplevel builds | succeed (`pipefail`) |
| Adapter sample payloads | bypass denied, plain command allowed, commit denied |
| `shellcheck` on the adapter | clean |
| Step 4 and step 5 probes | as listed |

## Rollback

Revert the squash-merged PR and redeploy. The mount options go back at the
next remount or reboot. There is no state to clean.

## Handoff note

Steps 1–3 edit three files, so the `coder` subagent implements steps 1–3.
Claude reviews the work and runs steps 4–6.
