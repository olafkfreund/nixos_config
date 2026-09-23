---
status: draft
issue: 1987
author: olafkfreund
---

# Intent: Stop playerctld segfaulting on a body-less D-Bus error

## Problem

`playerctld` (playerctl 2.4.1, unpatched nixpkgs) segfaults on p620 whenever
cliamp is one of the running MPRIS players. The bar (omarchy-shell) queries
playerctld on every start, playerctld forwards the call to the player, and the
reply crashes it within a second — so `Restart=on-failure` (commit 3867fc369)
just loops into systemd's start limit and the unit stays failed. Media keys and
the bar's player widget stop working until cliamp is closed.

Two NULL-dereference paths are proven from core dumps and the 2.4.1 source
(`playerctl/playerctl-daemon.c`):

1. `proxy_method_call_async_callback` — on an error reply it calls
   `g_variant_n_children(body)` without checking that `body` is non-NULL. A D-Bus
   error message with no body is legal, so any player that sends one kills the
   daemon. (It also reads child 1 where the error text is child 0.) Crashes at
   11:48:56–57, all with cliamp present; stable with only Chrome.
2. `context_emit_active_player_changed` — passes `player->player_properties` /
   `root_properties` to `g_variant_new_tuple` without checking them; they are
   NULL when fetching a player's properties failed. Crash at 11:42:15, preceded
   by `g_variant_ref_sink: assertion 'value != NULL' failed`.

Inferred, not captured: that cliamp is the player replying with a body-less
error. The code path is proven; the exact message is not.

Upstream altdesktop/playerctl master has the same code; the daemon file is
untouched since 2021-01 and v2.4.1 is still the latest release.

## Proposed outcome

On p620 and razer, with cliamp and Chrome both running, `playerctld` stays up across bar restarts
and player start/stop, media keys and the bar widget work, and no new
playerctld core dumps appear.

## Affected users and systems

- Hosts p620 (crash observed) and razer — both set
  `services.playerctld.enable = true` and both must get the fix.
- `playerctl` package (also provides the `playerctl` CLI used by keybindings).
- omarchy-shell's media widget, which talks to playerctld.

## Constraints

- Must not change cliamp or omarchy-shell; the fix belongs in playerctld.
- Must build from source locally: overriding playerctl loses the binary cache
  for that one small package, acceptable.
- Should be small and upstreamable, so it can be dropped when upstream fixes it.

## Open questions

- Scope: decided — p620 and razer.
- Also send the patch upstream to altdesktop/playerctl, or keep it local only?
