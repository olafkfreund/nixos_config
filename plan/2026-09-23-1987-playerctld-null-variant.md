---
status: approved
issue: 1987
spec: spec/2026-09-23-1987-playerctld-null-variant.md
---

# Plan: Stop playerctld segfaulting on a body-less D-Bus error

Branch `fix/1987-playerctld-null-variant`. Intent and spec approved.

## Approved decisions (carried from the spec)

- **Fix location:** a local C patch to playerctl 2.4.1 (`playerctl/playerctl-daemon.c`),
  applied via `overlays/upstream-fixes.nix` so `pkgs.playerctl` is patched for
  every host. This covers the daemon and the CLI with one build, so there's one
  playerctl on PATH.
- **Patch scope:** only the two proven crash sites.
  1. `proxy_method_call_async_callback`, error branch: read the error text only
     when `body != NULL`, it has ≥1 child and child 0 is a string. Otherwise
     reply `"Failed to call method"`. Child index corrected from 1 to 0.
  2. `context_emit_active_player_changed`: build and emit each
     `PropertiesChanged` tuple only when its cached properties
     (`player_properties` / `root_properties`) are non-NULL; otherwise
     `g_debug` and skip that one signal. `ActivePlayerChangeBegin`/`End` are
     unchanged.
- **Hosts:** p620 and razer. `Restart=on-failure` stays on p620 (3867fc369) and
  is added to razer.
- **Not doing:** changes to cliamp or omarchy-shell, building playerctl master,
  disabling playerctld, per-host package overrides, sending the patch upstream.
- **Accepted costs:** every host that uses playerctl builds it locally; the patch
  must be dropped or rebased when nixpkgs bumps playerctl (the build fails
  loudly if it no longer applies).

## Steps

1. **`overlays/playerctl-null-variant.patch` (new):** generate the patch as a
   real diff. Copy `playerctl-daemon.c` from the playerctl source
   (`nix build --inputs-from . nixpkgs#playerctl.src`) into a scratch dir, make
   both edits, and use `diff -u` with `a/playerctl/…` / `b/playerctl/…` paths
   (`-p1`, the stdenv default).
   Error branch after the edit:
   ```c
   case G_DBUS_MESSAGE_TYPE_ERROR: {
       const char *error_message = "Failed to call method";
       if (body != NULL && g_variant_n_children(body) > 0) {
           GVariant *msg = g_variant_get_child_value(body, 0);
           if (g_variant_is_of_type(msg, G_VARIANT_TYPE_STRING)) {
               g_dbus_method_invocation_return_dbus_error(
                   invocation, g_dbus_message_get_error_name(reply),
                   g_variant_get_string(msg, NULL));
               g_variant_unref(msg);
               break;
           }
           g_variant_unref(msg);
       }
       g_dbus_method_invocation_return_dbus_error(
           invocation, g_dbus_message_get_error_name(reply), error_message);
       break;
   }
   ```
   In `context_emit_active_player_changed`, wrap each tuple build and emit in
   `if (player->player_properties != NULL)` /
   `if (player->root_properties != NULL)`, with an `else g_debug(...)`.
   → verify by: `patch -p1 --dry-run` against a fresh copy of the source
   applies cleanly.

2. **`overlays/upstream-fixes.nix`:** add
   ```nix
   # playerctl 2.4.1's playerctld segfaults on a D-Bus error reply with no body
   # (e.g. from cliamp) and on NULL cached player properties (#1987). Upstream
   # daemon code is unchanged since 2021; kept local by decision.
   # Drop or rebase when nixpkgs bumps playerctl past 2.4.1.
   playerctl = prev.playerctl.overrideAttrs (old: {
     patches = (old.patches or [ ]) ++ [ ./playerctl-null-variant.patch ];
   });
   ```
   → verify by: `nix build --no-link --print-out-paths
   .#nixosConfigurations.p620.config.services.playerctld.package` succeeds, the
   log shows the patch applied, and the path is not `jlrc3mbz…`.

3. **`hosts/razer/configuration.nix`:** after the top-level
   `systemd.services.greetd.restartIfChanged = false;` (≈ line 462), add
   ```nix
   # playerctl 2.4.1 can segfault on a player signal (#1987); come back instead of staying failed.
   systemd.user.services.playerctld.serviceConfig.Restart = "on-failure";
   ```
   → verify by: `nix eval .#nixosConfigurations.razer.config.systemd.user.services.playerctld.serviceConfig --json`
   shows `Restart = "on-failure"` and the patched `ExecStart`, and razer's
   package path equals p620's.

4. **Commit** steps 1–3 together:
   `fix(playerctl): patch playerctld NULL-variant crashes (#1987)`.
   Leave the unrelated uncommitted `nixarchy-theme.nix` out.

5. **Build both hosts:** `nix build --no-link
   .#nixosConfigurations.{p620,razer}.config.system.build.toplevel`
   → verify by: both succeed.

6. **Deploy p620:** `nixarchy-apply --yes` → verify by: the new generation is
   active, and `readlink -f /run/current-system/sw/bin/playerctld` is the
   patched path.

7. **p620 runtime test (the original trigger):** start cliamp playing next to
   Chrome, run `systemctl --user reset-failed playerctld; systemctl --user
   restart playerctld`, restart omarchy-shell, then wait 60s.
   → verify by: `systemctl --user is-active playerctld` = `active`,
   `coredumpctl list playerctld` has no entries after the deploy time, and
   `busctl --user get-property org.mpris.MediaPlayer2.playerctld
   /org/mpris/MediaPlayer2 org.mpris.MediaPlayer2.Player PlaybackStatus` answers.
   Also call `… Shuffle` on playerctld: it returns a D-Bus error to the caller
   and the daemon stays `active`.

8. **Deploy razer:** `just deploy-fast razer` (the repo's `nixos-rebuild switch
   --target-host razer --build-host razer`; it does not update flake inputs).
   → verify by: over SSH, `systemctl --user is-active playerctld` and
   `coredumpctl list playerctld --since <deploy time>` show no new cores. If
   razer is unreachable, stop here and report "razer: build-verified only".

9. **Close out:** push the branch and open a PR linking the intent, spec and
   plan and closing #1987.

## Tests

| Check | Command | Expected |
| --- | --- | --- |
| Patch applies | `patch -p1 --dry-run < overlays/playerctl-null-variant.patch` in a fresh source copy | no rejects |
| Package builds | `nix build .#nixosConfigurations.p620.config.services.playerctld.package` | success, new path |
| Same on both hosts | compare p620 and razer `services.playerctld.package.outPath` | identical |
| razer unit | `nix eval …razer…playerctld.serviceConfig --json` | `"Restart":"on-failure"` |
| Hosts build | toplevel build for p620 and razer | success |
| Original trigger | cliamp + Chrome playing, restart playerctld + bar, wait 60s | `active`, no new cores |
| Error path | `busctl … playerctld … Shuffle` | D-Bus error returned, daemon alive |

## Rollback

- **Runtime, immediate:** `sudo nixos-rebuild --rollback switch` on the affected
  host. On p620 the previous generation is 2634; on razer, whichever was active
  before step 8.
- **Code:** `git revert` the step-4 commit. This removes the patch, the overlay
  entry and the razer `Restart=` line together. p620's `Restart=` (3867fc369)
  is independent and stays.
- **Workaround if the patch is reverted:** keep cliamp closed while playerctld
  is needed.
