---
status: draft
issue: 2409
author: olafkfreund
---

# Intent: nightly upgrade must not switch to a stale cached flake

## Problem

`system.autoUpgrade` (`modules/nix/nix.nix`) runs `nixos-rebuild switch
--refresh --flake github:olafkfreund/nixos_config` every night at 04:00, plus up
to 45 minutes of random delay. If GitHub cannot be reached, Nix logs "unable to
download ... using cached version" and goes ahead with whichever copy of the
flake it last fetched. That copy can be days or weeks old.

On 2026-10-21 at 04:31, DNS was down after a router event. p620 and razer
were switched to about 04a6fbd63 (nixpkgs fe13242), 19 commits behind main.
That undid #2391 to #2405. p620's 07:42 reboot then made the old
generation the boot default. The unit reported success, so the rollback went
unnoticed until hours later.

## Proposed outcome

- When GitHub is unreachable at upgrade time, the nightly run changes nothing
  on the host. The journal says why it skipped, and the next night tries
  again.
- When GitHub is reachable, the nightly run behaves exactly as it does today.

## Affected users and systems

- p620 and razer, through `modules/nix/nix.nix`.
- p510 has `system.autoUpgrade.enable = lib.mkForce false` and is
  unaffected.
- The p510 nixvm microvm has its own `system.autoUpgrade`
  (`hosts/p510/nixos/microvm/nixvm.nix`) and is out of scope unless the
  approver wants it included.
- Manual deploys (`just`, `nhs`) are untouched.

## Constraints

- Must not change the behaviour of a run that can reach GitHub.
- Must not leave a failed unit just because the network was down. A failed
  `nixos-upgrade.service` would make later deploys report errors.
- Keep the change inside `modules/nix/nix.nix`, with no new module or option.

## Open questions

- Should a skipped night be silent apart from the journal, or should the
  unit show as failed so `systemctl --failed` reveals it? This intent assumes
  the journal is enough.
- Should the nixvm microvm get the same guard?
