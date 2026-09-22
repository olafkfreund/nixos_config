---
status: approved
issue: 1954
spec: spec/2026-09-22-1954-razer-two-boot-entries.md
---

# Plan: razer keeps at least two boot entries

Approved decisions, carried over from the spec:

- razer only. The ESP stays 511 MiB. NVIDIA stays in the initrd, so early
  KMS and PRIME sync are unchanged.
- `hardware.nvidia.package` in `hosts/razer/nixos/nvidia.nix` becomes
  `nvidiaPackages.latest.overrideAttrs`, with a `postFixup` that runs
  `rm $firmware/lib/firmware/nvidia/*/*tu10x*`. The `rm` has no `-f`, so a
  renamed file fails the build instead of passing quietly. A comment names
  the GA104 (Ampere) and says to drop the override if razer ever gets a
  Turing card.
- Measured: initrd 131 → 117 MiB. The firmware left inside is only
  `gsp_ga10x.bin` and `ucodes_ga10x.bin`. `ucodes_ga10x.bin` stays because
  the GPU needs it.
- `configurationLimit = 2` in `hosts/razer/nixos/boot.nix`. The comment is
  rewritten around the new budget and keeps the history:
  ~131 MiB per generation, ~265 MiB used normally (~246 MiB free), and a
  deploy peak of ~395 MiB (~115 MiB headroom). It overflows only past a
  ~155 MiB initrd.
- `scripts/check-boot-space.sh`: only the razer comment's figures are
  refreshed. `MIN_FREE_MIB = 200` and the escalate-to-one fallback stay.
- The driver override builds on p620. It is unfree, so it is never cached
  anyway. The open kernel module does not rebuild.
- Deploy with `just deploy-via-p620 razer`, announced on the bus. Reboot to
  prove the new boot. The second entry appears from the next deploy on.

## Steps

1. `hosts/razer/nixos/nvidia.nix`: replace the `package = ...latest;`
   line with the override and its comment.
   → verify: build razer's `initialRamdisk`. The NVIDIA firmware inside is
   exactly the two `ga10x` files, and the file is ~117 MiB.
2. `hosts/razer/nixos/boot.nix`: `configurationLimit = 1` becomes `2`, and
   the comment is rewritten with the budget above.
   → verify: `nix eval .#nixosConfigurations.razer.config.boot.loader.systemd-boot.configurationLimit`
   returns `2`.
3. `scripts/check-boot-space.sh` (lines 81-89): update the razer figures
   in the escalation comment and say that razer now keeps 2 generations.
   Comment only.
   → verify: `bash -n scripts/check-boot-space.sh`, and `git diff` shows
   only comment lines.
4. Evaluate all hosts and build razer.
   → verify: `nix eval` of `toplevel.drvPath` passes for p620, razer and
   p510. p620's and p510's drvPaths match `origin/main`, so their
   closures are unchanged. `just test-host razer` exits 0.
5. Commit as `feat(razer): keep two boot entries, drop unused Turing
   firmware (#1954)`, push, and open a PR linking the intent, spec and
   plan. Stop for the merge.
6. After the merge, and with the user's go-ahead: read the bus, post the
   deploy, then run `just deploy-via-p620 razer`. The user reboots razer.
   → verify on the new boot: `nvidia-smi -L` lists the RTX 3080,
   `journalctl -k -b | grep -iE 'gsp|firmware.*nvidia'` shows no errors,
   and `systemctl --failed` is empty.
7. After the next razer deploy:
   → verify: `bootctl list` shows two NixOS generations, and
   `df -m /boot` shows ≥ 200 MiB free.

## Tests

- initrd firmware list and size: step 1.
- The limit evaluates to 2: step 2.
- `bash -n` on the guard script: step 3.
- The three hosts evaluate, p620 and p510 are unchanged, and razer
  builds: step 4.
- pre-commit and pre-push hooks pass: step 5.
- Runtime GPU and boot-menu checks on razer: steps 6 and 7.

## Rollback

- **Before the deploy:** `git revert` the squash commit.
- **After the deploy, if razer boots but the GPU misbehaves:** pick the
  previous generation from the boot menu, which step 6 keeps, or run
  `sudo nixos-rebuild --rollback switch`. Then revert the commit and
  redeploy.
- **If razer does not boot at all:** the first deploy writes the new
  generation next to the old one, so the old entry is still in the menu.
  Choose it, then revert.
