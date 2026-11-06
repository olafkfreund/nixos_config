---
status: approved
issue: 2746
intent: intent/2026-11-06-2746-gnome-keyring-open-session-abort.md
---

# Spec: Stop gnome-keyring crashes from locking the keyring

## Decisions carried from the intent

- Fix p620 first, then razer. p510 only when asked.
- This task also looks into why prompts outnumber crashes. A different fix gets
  its own issue.
- Stopping the crash is accepted as the answer to the missing password dialog
  for now. Reopen this if it happens without a crash.

## Design

### 1. Patch `service_method_open_session`

Add `overlays/gnome-keyring-open-session-null-output.patch` against
`daemon/dbus/gkd-secret-service.c`. After `gkd_secret_session_handle_open`
returns, turn "no error and no output" into an error:

```c
if (error == NULL && output == NULL) {
 g_set_error_literal (&error, G_DBUS_ERROR, G_DBUS_ERROR_FAILED,
        "Couldn't negotiate session");
}
```

The check sits in the shared caller, so it covers `aes_negotiate` and
`plain_negotiate` without touching either. The existing `error != NULL` branch
then replies with the error and skips publishing the session. The session object
is released by the `g_object_unref` already at the end of the function. When the
caller has already left, nobody receives that reply, so the tests can only observe
the daemon surviving and still serving other clients. The error reply itself is
established by reading the code.

### 2. Apply it through the existing overlay

Add to `overlays/upstream-fixes.nix`, in the same shape as the `playerctl` entry:

```nix
gnome-keyring = prev.gnome-keyring.overrideAttrs (old: {
  patches = (old.patches or [ ]) ++ [ ./gnome-keyring-open-session-null-output.patch ];
});
```

The comment names #2746 and says to drop or rebase the patch when upstream fixes
this. The overlay is flake-wide, so every host picks it up at its next deploy.
Rollout order is controlled by which host is deployed when.

### 3. Keep the reproducer

Add `scripts/test-gnome-keyring-open-session.sh`, taking a package path. It starts
the daemon on a private bus (`dbus-run-session`) with a temporary `HOME`, then
fires bursts of `OpenSession` from `busctl --expect-reply=no` clients that exit
without waiting. It reports one of: daemon died, survived with the assertion hit,
or survived without hitting it. The last result proves nothing, so the script
must not report it as a pass. It never touches the real keyring, but an abort on
the unpatched daemon does reach `coredumpctl`, even with `ulimit -c 0`. Lab runs
therefore have to be separated from real crashes by time.

It stays in the repo because the patch has to be rechecked whenever nixpkgs moves
`gnome-keyring`.

### 4. Check the extra prompts

Nine prompts started on 6 November against two crashes. One untested explanation
is that the keyring stayed locked after each crash and every later client asked
again. After the deploy, compare the timestamps of prompter starts and crashes for
7 days. A count alone cannot test this, so record whether each prompt had a crash
before it with no successful unlock in between:

```bash
journalctl --user --since '-7 days' --no-pager -g 'Started dbus.*SystemPrompter'
coredumpctl list --since '-7 days' --no-pager | grep keyring
```

If the explanation holds, prompts should nearly stop with the crashes. Any prompt
in a session with no crash and no user lock disproves it, and that goes to a new
issue.

Also worth watching: the journal shows `discover_other_daemon: 1` 25 times since
3 November, and two declarations (`services.gnome.gnome-keyring` in
`modules/services/gnome/gnome-services.nix:12` and `services.gnome-keyring` in
`home/desktop/gnome/default.nix:75`) that can each start a daemon. If prompts
continue without crashes, this is the first place to look, under a new issue.

### 5. Report upstream

After verification, file the bug with the reproducer and the patch at
gnome-keyring's GitLab, after checking whether it is already fixed there.

## Evidence so far

From a scratchpad build of this patch on the current nixpkgs input, using a
private bus:

| Algorithm | Runs | Current daemon | Patched daemon |
| --------- | ---- | -------------- | -------------- |
| `plain` | 4 | Aborted in 3, with the journal's `g_variant_new` error | Survived all 4; the assertion fired in 3 |
| AES | 7 | Survived; assertion not hit | Survived; assertion not hit |

A second reproducer froze the daemon with `SIGSTOP` while clients sent and exited,
then resumed it. It hit nothing on either algorithm in 3 runs per daemon, so a
client being gone before its call is handled is not enough. The race is tighter
than that, and its exact order is unknown.

So clients exiting mid-call can trigger this abort on the `plain` path. **The AES
path, which is the one the journal shows on p620, has not been reproduced in the
lab.** From the source, its failure returns through the same patched check, but
that is reading the code, not a test. Attempts stopped here after two approaches
failed. The direct proof comes from p620 itself, in Verification step 4.

## Alternatives rejected

- **Find and fix the client:** any client that exits mid-call can trigger this,
  so the daemon still needs the fix.
- **Restart the daemon automatically:** systemd already does. The unlock is lost
  either way.
- **Move tokens out of the keyring:** ruled out by the intent, and it leaves the
  crash for every other client.
- **Patch only the consumers that matter:** the NixOS module has no `package`
  option and uses `pkgs.gnome-keyring` directly for the wrapper, PAM and D-Bus
  files, so a partial override would leave mismatched copies.
- **Fix each negotiate function:** two changes where one in the shared caller
  covers both.

## Risks

- **Rebuild cost:** a dry run of `gnome-shell`'s closure rebuilds `gnome-shell`
  and one helper patch, on top of `gnome-keyring`. The full p620 closure still
  has to be measured before deploying. Stop and ask if any compiled package beyond
  those two rebuilds.
- **A bump can break the build:** if nixpkgs changes that code, the patch stops
  applying and the build fails. That is loud, which is preferred to a silently
  dropped fix.
- **The running daemon keeps the old binary:** a deploy doesn't replace a
  dbus-activated daemon. The fix takes effect at the next login, or when the unit
  is stopped, which means one unlock.
- **The deploy may start a second daemon:** Home Manager started
  `gnome-keyring.service` during the 14:29 activation on 6 November. The effect on
  the unlock is unknown, so check the lock state and the daemon count right after
  deploying.
- **Lab runs inflate the crash record:** 3 of the 5 keyring entries in `coredumpctl`
  for 6 November came from building this evidence. The 7-day window starts after the
  last lab run on that host.
- **`gnome-shell` rebuilt locally:** low risk, same source and inputs, but a GNOME
  session on any host would run the local build.

## Verification

1. `just check-syntax`, then `just test-host p620`, and measure what actually
   rebuilds.
2. Run the reproducer against current and patched packages on the `plain` path.
   Current must abort in at least one run; patched must never abort and must hit
   the assertion in at least one run. This proves the `plain` path only.
3. After deploying p620 and logging in again: exactly one daemon is running, it is
   the patched store path, the keyring is unlocked, and
   `timeout 10 gh auth status` succeeds.
4. Over 7 days on p620, starting after the last lab run: no aborts with this
   signature, and the prompter comparison above. p620 had 5 real aborts in the 4
   days before, so a quiet week means something. The AES path counts as proven
   only if the journal shows `aes_negotiate: assertion 'session' failed` with the
   daemon still running afterwards. A quiet week without that line means "no
   crashes seen", and the report must say so.
5. razer, after p620 has been deployed and checked: build with
   `just deploy-via-p620 razer`, then repeat step 3 there. razer has shown no
   crashes, so its 7-day check is only that none appear.
6. p510 is outside this task's verification unless you ask. It picks up the patch
   at its next deploy, because the overlay is flake-wide.
