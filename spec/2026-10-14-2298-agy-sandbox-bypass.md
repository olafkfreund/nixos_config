---
status: approved
issue: 2298
intent: intent/2026-10-14-2298-agy-sandbox-bypass.md
---

# Spec: agy-implement's sandbox holds, and agy cannot bypass it

## Findings

Traced on p620 on 2026-10-14 with agy 1.3.4, using `strace` and a raw
`mount(2)` reproduction from Python.

### 1. Why the sandbox server resets

agy's sandbox is agy itself, re-executed as PID 1 in new user, mount and PID
namespaces. It does not use bwrap. While setting up its root, it
bind-mounts `/bin` and then calls:

```text
mount("", ".../bin", NULL, MS_RDONLY|MS_REMOUNT|MS_BIND) = -1 EPERM
sbox: remount /bin: operation not permitted
```

The child exits with status 1. The parent then sees
`connecting to sandbox server: ... connection reset by peer`.

- **What is on `/bin`.** On every host, `/bin` and `/usr/bin` are envfs FUSE
  mounts (`services.envfs`, enabled through nixarchy). FUSE adds `nosuid` and
  `nodev` by default.
- **Why the remount fails.** Inside a user namespace those flags are
  locked. A remount that does not repeat them gets EPERM, and agy's does not
  repeat them.
- **Reproduction.** The same raw syscall fails with only `MS_RDONLY`, fails
  with `MS_NOSUID` alone, and succeeds with `MS_NOSUID|MS_NODEV` added.
- **The fix, tested.** In a private mount namespace with `/bin` and
  `/usr/bin` remounted `suid,dev`, agy's sandbox started and ran the command.

The mounts have not changed since boot, so the sandbox never worked on
these hosts. The runs earlier on 2026-10-14 that looked sandboxed were
almost certainly agy's silent `BypassSandbox: true` retries.

### 2. The workspace is read-only inside the terminal sandbox

With the sandbox working, agy remounts the workspace and its `.git`
read-only (`MS_RDONLY|MS_REMOUNT|MS_NOATIME|MS_BIND`). So a sandboxed
`echo >> f.txt` fails with "Read-only file system". This happens:

- with `--add-dir`;
- with the directory in `trustedWorkspaces`;
- under `/tmp` and under `/home`.

It is agy's design: edits go through the file tools, and terminal commands
are read-only. That suits `agy-implement`, because file edits are already
fenced to the worktree by the guard (#2299). Commands that only read, or
that write through a daemon, still work: `nix build`, `nix eval`,
`just check-syntax`, `git diff`.

### 3. The bypass

`run_command` with `BypassSandbox: true` runs unconfined, and under
`--dangerously-skip-permissions` nothing prompts.

## Design

1. **Turn off `nosuid` and `nodev` on the envfs mounts.** The module is
   `modules/programs/claude-code-managed.nix`, which already installs the
   agy guard to `/etc/antigravity`. Under `lib.mkIf config.services.envfs.enable`
   (the module's existing style), add:

   ```nix
   fileSystems."/usr/bin".options = [ "suid" "dev" ];
   fileSystems."/bin".options = [ "suid" "dev" ];
   ```

   These lists merge with the nixpkgs envfs options. They are harmless:
   envfs only serves symlinks to binaries on `PATH`, so setuid and device
   handling follow the mount of the target, not the envfs mount. A one-line
   comment gives the agy reason.

2. **The adapter denies the bypass.** In
   `modules/programs/agy-guard-adapter.sh`, a `run_command` whose
   `.toolCall.args.BypassSandbox` is `true` is denied with "agy-implement
   may not bypass the sandbox (#2298)". This sits before the guard call.
   Plain agy is unaffected, because the adapter allows everything when
   `AGY_CODER` is not 1.

3. **The `handoff` skill.**
   - State that shell commands run read-only in the sandbox, so edits must
     use agy's file tools. Put that in the prompt template.
   - Add two checks to the after-update probe:
     - a sandboxed read-only command succeeds (for example `git status`);
     - a `BypassSandbox` attempt is denied.

4. **Upstream.** File the remount bug with google-antigravity/antigravity-cli.
   The remount should repeat the source mount's locked flags. The issue
   includes the reproduction. Our mount change stays until agy is fixed.

## Alternatives rejected

- **Option B: drop `--sandbox`.** The user chose A.
- **Remount `/bin` per agy run in a private namespace.** That needs root on
  every run, which is far more machinery than two mount options.
- **Disable envfs.** It is enabled by nixarchy, and `/bin/bash` shebangs
  depend on it.
- **Make the workspace writable for terminal commands.** No setting tried
  does this (`--add-dir`, trust). Edits through the file tools are fenced
  and reviewed, which is the safer shape anyway.

## Risks

- **The change reaches all three hosts.** `claude-code-managed.nix` is
  shared, so p510 gets it at its next approved deploy. The effect there is
  the same and harmless.
- **The remount may not apply on switch.** Changing options on a mounted
  FUSE filesystem through a switch may need a reboot. If it does not take
  effect, verification shows it, and p620 and razer need a reboot, or a
  manual `mount -o remount,suid,dev`, announced on the bus.
- **Tests that write caches** (such as `.pytest_cache`) may warn in the
  read-only sandbox. Steps that need writes from commands must be done by
  Claude, not agy.
- **An agy update may change the sandbox.** The after-update probe catches
  that.

## Verification

1. `just check-syntax`, then p620 and razer toplevel builds with `pipefail`.
   `nix eval` shows `suid` and `dev` in both `fileSystems` entries.
2. After deploying p620:
   - `/proc/self/mountinfo` shows `/bin` and `/usr/bin` without
     `nosuid,nodev`.
   - Plain `agy --sandbox -p "run git status"` succeeds sandboxed, with no
     connection reset.
3. `agy-implement` in a scratch git repo under `/home`:
   - `write_to_file` inside the worktree is written;
   - the commit is blocked;
   - the `~/.gemini` touch is blocked;
   - a write outside the worktree is blocked;
   - a forced `BypassSandbox: true` attempt is denied with the new message;
   - a sandboxed `git status` succeeds.
4. The same on razer after its deploy.
5. Unit tests of the adapter with sample payloads (bypass denied, normal
   command allowed).
6. The upstream issue is filed, and its URL is in the PR.
