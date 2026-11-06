---
status: draft
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
is released by the `g_object_unref` already at the end of the function.

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
must not report it as a pass. It disables core dumps and never touches the real
keyring.

It stays in the repo because the patch has to be rechecked whenever nixpkgs moves
`gnome-keyring`.

### 4. Check the extra prompts

Nine prompts started on 6 November against two crashes. One untested explanation
is that the keyring stayed locked after each crash and every later client asked
again. After the deploy, compare prompter starts with crashes for 7 days:

```bash
journalctl --user --since '-7 days' --no-pager -g 'Started dbus.*SystemPrompter'
coredumpctl list --since '-7 days' --no-pager | grep keyring
```

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
| AES | 1 | Survived; assertion not hit | Survived; assertion not hit |

So a client exiting mid-call does trigger this abort. The AES path, which the
journal shows on p620, has not been reproduced yet. Its failure takes the same
route through the patched check, but that is from reading the source.

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
  has to be measured, and the plan does that before deploying.
- **A bump can break the build:** if nixpkgs changes that code, the patch stops
  applying and the build fails. That is loud, which is preferred to a silently
  dropped fix.
- **The running daemon keeps the old binary:** a deploy doesn't replace a
  dbus-activated daemon. The fix takes effect at the next login, or when the unit
  is stopped, which means one unlock.
- **The deploy may start a second daemon:** Home Manager started
  `gnome-keyring.service` during the 14:29 activation on 6 November. The effect on
  the unlock is unknown, so check the lock state right after deploying.
- **`gnome-shell` rebuilt locally:** low risk, same source and inputs, but a GNOME
  session on any host would run the local build.

## Verification

1. `just check-syntax`, then `just test-host p620`, and measure what actually
   rebuilds.
2. Run the reproducer against current and patched packages. Current must abort in
   at least one run; patched must never abort and must hit the assertion in at
   least one run. Try to hit the AES path too, and report plainly if it isn't hit.
3. After deploying p620 and logging in again: the running daemon is the patched
   store path, the keyring is unlocked, and `timeout 10 gh auth status` succeeds.
4. Over 7 days on p620: no aborts with this signature, and the prompter comparison
   above.
