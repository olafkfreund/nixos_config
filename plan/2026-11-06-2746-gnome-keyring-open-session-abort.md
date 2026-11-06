---
status: approved
issue: 2746
spec: spec/2026-11-06-2746-gnome-keyring-open-session-abort.md
coders:
  1: coder # small file copied verbatim from this plan, nothing to decide
  2: coder # one overlay entry in an established pattern
  3: codex # small but tricky: the result classification must never call an inconclusive run a pass
reviewers:
  - codex # independent read of the C change and the exit-code logic
---

# Plan: Stop gnome-keyring crashes from locking the keyring

`gnome-keyring-daemon` 50.0 aborts when `OpenSession` fails without setting an
error: `service_method_open_session` passes a NULL output to
`gkd_exported_service_complete_open_session`. The fix turns "no error, no output"
into a D-Bus error in that shared caller, delivered through the existing overlay.
A reproducer stays in the repo.

Approved decisions: p620 first, then razer, p510 only when asked. The extra
prompts are checked here, and a different cause gets a new issue. The missing
password dialog is assumed to go with the crash until shown otherwise.

Known limit: the lab reproduces the `plain` path only. The AES path, which is what
crashes on p620, is proven only by step 8's journal check.

Work in the worktree `/home/olafkfreund/.config/nixos-2746` on branch
`fix/2746-gnome-keyring-open-session-abort`. Never check out a branch in
`~/.config/nixos`.

## Steps

1. Create `overlays/gnome-keyring-open-session-null-output.patch` with exactly
   this change. The block below shows it, but the repo's Markdown formatter strips
   tabs from it, so do not copy its whitespace. Generate the file instead: unpack
   `nixpkgs#gnome-keyring.src`, make the edit in
   `daemon/dbus/gkd-secret-service.c` using tabs like the code around it, and write
   the result with `diff -u` using `a/` and `b/` paths:

   ```diff
   --- a/daemon/dbus/gkd-secret-service.c
   +++ b/daemon/dbus/gkd-secret-service.c
   @@ -433,6 +433,11 @@
         &error);
     g_variant_unref (input_payload);

   + if (error == NULL && output == NULL) {
   +  g_set_error_literal (&error, G_DBUS_ERROR, G_DBUS_ERROR_FAILED,
   +         "Couldn't negotiate session");
   + }
   +
     if (error != NULL) {
      g_dbus_method_invocation_take_error (invocation, error);
     } else {
   ```

   → verified by the build in step 2.
   Traps: `.patch` files must keep their tabs, or the patch stops applying. Check
   with `grep -P '\t' overlays/gnome-keyring-open-session-null-output.patch`.

2. `overlays/upstream-fixes.nix`, after the `playerctl` entry that ends at line 49,
   add:

   ```nix
   # gnome-keyring 50.0 aborts when OpenSession fails without setting an error,
   # which loses the login unlock (#2746). Drop or rebase once upstream fixes it.
   gnome-keyring = prev.gnome-keyring.overrideAttrs (old: {
     patches = (old.patches or [ ]) ++ [ ./gnome-keyring-open-session-null-output.patch ];
   });
   ```

   → run `git add overlays/gnome-keyring-open-session-null-output.patch` first,
   then verify with `just check-syntax`, then
   `nix build --no-link .#nixosConfigurations.p620.pkgs.gnome-keyring`.
   Traps: flakes ignore untracked files, so an unstaged patch fails the build.
   Services belong in `modules/`, but this is a package patch, so the overlay is
   the right place. Use `set -o pipefail` if piping a `nix build`.

3. Create `scripts/test-gnome-keyring-open-session.sh`, executable, usage
   `<gnome-keyring store path> [plain|aes] [runs, default 4]`. For each run, under
   its own `dbus-run-session` with a temporary `HOME`, `XDG_DATA_HOME`,
   `XDG_RUNTIME_DIR` and `XDG_CONFIG_HOME`:

   - start `"$pkg/bin/gnome-keyring-daemon" --foreground --components=secrets`,
     logging to a file, and wait for `org.freedesktop.secrets` on the bus
   - make one call that waits for its reply. Success means `busctl` exits 0 and prints
     a session path. Otherwise the run counts as failed, not as evidence
   - send 40 rounds of 8 parallel calls with `--expect-reply=false`, stopping early
     if the daemon has died:

     ```bash
     busctl --address="$DBUS_SESSION_BUS_ADDRESS" --expect-reply=false call \
       org.freedesktop.secrets /org/freedesktop/secrets \
       org.freedesktop.Secret.Service OpenSession "$@"
     ```

     `plain` passes `sv plain s ""`. `aes` passes
     `sv dh-ietf1024-sha256-aes128-cbc-pkcs7 ay 128` followed by the value `7` repeated
     128 times, as `$(seq 1 128 | sed 's/.*/7/')`.
   - if alive, make one more waiting call, with the same success test
   - count `assertion 'client' failed` in the log and delete the temporary home

   Print one line per run, then a summary. Exit codes: `1` if any run aborted, `0`
   only if none aborted and the assertion fired in at least one run, and `2` if
   nothing aborted and the assertion never fired, because that proves nothing.

   → verify with `shellcheck`, then step 5.
   Traps: never touch the real keyring or the real session bus. `ulimit -c 0` does
   not stop aborts reaching `coredumpctl`, so say that in a one-line comment. Bash
   tool stdin is a socket, so do not read stdin to EOF.

4. Measure the real rebuild: `just test-host p620`, and list what was built. Stop
   and ask if any compiled package other than `gnome-keyring` and `gnome-shell`
   (plus its helper patch) rebuilds.
   Traps: do not run `nhs`. Check nothing else is mid-build first.
   Result on 2026-11-06: beyond those two, the overlay also rebuilds `gnome-session`,
   `gnome-tweaks`, `gnome-browser-connector`, the `firefox` wrapper and `github-desktop`,
   and downloads 1.1 GiB. The owner accepted this and the ongoing cost on later
   `nixpkgs` updates.

5. Run the reproducer on both packages, `plain` path: the current store path must
   exit `1` in at least one invocation, and the patched path must exit `0`. Then run
   `aes` on both and report the result as it is. Exit `2` there is expected and is
   not a failure of this plan. Note the time of the last run.

6. Commit steps 1 to 3, naming the plan steps. Push, confirm the remote head matches,
   open the PR linking the intent, spec and plan, and saying which steps which coder
   did. Comment `@codex review`. Review with a fresh Opus agent given only this plan
   path and `git diff`, plus the `reviewers:` above. Merge once review is clean.
   Traps: write commit and PR text to a file (`-F`, `--body-file`): the bus guard
   matches words in command text, and backticks in `-m` run as commands. Merge main
   into the branch first if it has moved.

7. Run `just validate` and `just test-host p620` on the merged `main`; both must pass.
   Deploy p620 from `main`. Read `#agents:freundcloud.org.uk`, post the plan and how
   long it takes, then run `AGENT_BUS_ANNOUNCED=1 just p620`. Record the finish time as
   an exact timestamp.
   Traps: exit 4 from an unrelated unit is a known pattern, so read which unit failed
   before reacting. Do not run `omarchy` restarts as part of this.
   Then, right after the deploy and before the next login, check the lock state and
   daemon count, in case Home Manager started another daemon. Then **ask you to log
   out and in**, or to approve stopping the daemon unit, which needs one unlock.
   Confirm: exactly one daemon, running the patched store path, keyring unlocked,
   and `timeout 10 gh auth status` succeeds.

8. Over at least 7 days on p620. Set `START` to the later of step 5's last run and the
   deploy finish, as a fixed timestamp recorded on #2746. Check back once that week is
   over, using that timestamp however late the check runs:

   ```bash
   journalctl --user --since "$START" --no-pager -t gnome-keyring-daemon -g "aes_negotiate: assertion|g_variant_new: expected"
   journalctl --user --since "$START" --no-pager -g 'Started dbus.*SystemPrompter'
   coredumpctl list --since "$START" --no-pager | grep keyring
   ```

   Pass: no aborts. If the `aes_negotiate` line appears with the daemon still running
   after it, report that the AES path failed and the patched daemon survived. That the
   new check handled it is from reading the source. Without that line, the report says
   "no crashes seen". For each prompt, record whether a crash came before it with no unlock in
   between. A prompt with no crash and no user lock disproves the explanation, and
   gets a new issue starting from `discover_other_daemon` and the two daemon
   declarations.

9. razer, after step 7's checks pass: `just test-host razer` must pass, then post on
   the bus, then
   `AGENT_BUS_ANNOUNCED=1 just deploy-via-p620 razer`. Repeat step 7's checks there,
   and its own 7-day no-crash check. razer's 511 MiB ESP and its known cosmetic exit 4
   both apply. p510 is not touched. It picks up the patch at its next deploy, so tell
   you when that happens.

10. Report upstream: check gnome-keyring's GitLab for an existing fix or issue. If it
    is not fixed, file it with the reproducer and patch. If it is fixed, note the
    commit in the overlay comment. Close #2746 only after steps 8 and 9 both finish.

## Tests

| Check | Expected |
| ----- | -------- |
| `just check-syntax` | Passes |
| `just test-host p620` | Builds; only the expected packages rebuild |
| `shellcheck scripts/test-gnome-keyring-open-session.sh` | Clean |
| Reproducer, current, `plain` | Exit 1 in at least one invocation |
| Reproducer, patched, `plain` | Exit 0 |
| After deploy | One patched daemon, unlocked, `gh auth status` works |
| 7 days on p620 | No aborts; AES result stated exactly as seen |

## Rollback

Revert the merge commit on `main` and deploy p620. To undo immediately, switch to the
previous generation:

```bash
sudo nixos-rebuild switch --rollback
```

The old daemon binary returns at the next login or daemon stop, with the bug back.
No keyring files are changed by this work, so there is nothing to restore.
