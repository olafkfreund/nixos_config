---
status: draft
issue: 2298
author: olafkfreund
---

# Intent: agy-implement's sandbox holds, and agy cannot bypass it

Follows `intent/2026-10-14-2296-agy-skip-permissions.md`.

## Problem

`agy-implement` runs agy with `--sandbox` and `--dangerously-skip-permissions`
under the coder guard (#2296). Two things undermine that sandbox:

1. **The sandbox server is broken.** Since about 12:40 on 2026-10-14, every
   sandboxed `run_command` on p620 and razer fails with:

   ```text
   connecting to sandbox server: read unix @->@: recvmsg: connection reset by peer
   ```

   - It also happens with plain `agy`, without the wrapper.
   - bwrap works on its own and has not changed.
   - The sandbox worked earlier the same day.

2. **agy escapes the sandbox.** After a sandboxed command fails, agy retries
   it with `BypassSandbox: true`. Under the flag nothing asks first, and the
   coder-guard adapter does not check that argument. So `--sandbox` is
   advisory: the only limit on an unsandboxed command is the guard's
   blocklist. That retry also reported exit 0 without editing the
   worktree file, so it may have run in another directory.

Together, these make agy handoffs that need a shell command either fail or
run outside the sandbox.

## Proposed outcome

- **The bypass is refused.** The guard adapter denies any `run_command` that
  asks to bypass the sandbox, while `AGY_CODER=1`. Plain agy is unaffected.
- **The sandbox works again** on p620 and razer: a sandboxed `run_command`
  in a worktree succeeds. The cause is found and fixed in this repo if it is
  ours, or reported upstream with a workaround if it is agy's.
- **Proof** on both hosts:
  - a sandboxed edit command succeeds;
  - a bypass attempt is denied by the guard;
  - the earlier probe still passes: the commit, the `~/.gemini` write and
    the outside write are blocked.
- **The handoff skill's post-update probe** includes the bypass check.

## Affected users and systems

- **Guard:** `modules/programs/agy-guard-adapter.sh`.
- **Possibly:** `home/development/antigravity-config.nix` or host
  configuration, depending on the sandbox cause.
- **Rules:** the `handoff` skill.
- **Hosts:** p620 and razer. p510 only with your approval.

## Constraints

- **Fail closed.** While the sandbox is broken, handoffs that need a shell
  command must fail visibly, never fall back to running unsandboxed.
- **The rest of the guard stays.** The `.gemini` fence and the worktree
  write fence from #2296 remain.
- **Subscription login only** (#1831).

## Open questions

None. The user chose option A on 2026-10-14.
