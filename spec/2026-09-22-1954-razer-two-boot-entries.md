---
status: approved
issue: 1954
intent: intent/2026-09-22-1954-razer-two-boot-entries.md
---

# Spec: razer keeps at least two boot entries

## Design

Two changes, both razer-only.

### 1. Drop the Turing firmware from razer's NVIDIA package

In `hosts/razer/nixos/nvidia.nix`, `hardware.nvidia.package` becomes an
override of the current `nvidiaPackages.latest` that deletes the Turing
firmware from the driver's `firmware` output:

```nix
package = config.boot.kernelPackages.nvidiaPackages.latest.overrideAttrs (old: {
  postFixup = (old.postFixup or "") + ''
    rm $firmware/lib/firmware/nvidia/*/*tu10x*
  '';
});
```

NixOS takes the initrd's firmware from `hardware.firmware`, and the
nvidia module fills that from `package.firmware`. Filtering the package
therefore removes the files from both the initrd and the running system.
There is no option that excludes files from the initrd alone.

A comment next to it says why, names the GPU (GA104, Ampere), and notes
that the override must go if razer ever gets a Turing card.

**Measured on 2026-09-22** by building razer's initrd with this override,
without committing it:

| | Before | After |
| --- | --- | --- |
| initrd on the ESP | 131 MiB | 117 MiB |
| NVIDIA firmware in initrd | ga10x + tu10x (4 files) | `gsp_ga10x.bin`, `ucodes_ga10x.bin` |

The Turing files are 30 MiB uncompressed but only 14 MiB after zstd. The
intent's rough "~100 MiB" was an estimate; this is the real number.

What rebuilds, from the dry run: `nvidia-x11` (repacks the unfree driver,
which is never cached anyway), `nvidia-settings`, the firmware set, the
initrd, and the usual system paths. The open kernel module does **not**
rebuild; it keeps its own reference to the driver source.

### 2. Raise the boot-entry limit to 2

`hosts/razer/nixos/boot.nix`: `configurationLimit = 2`. The long comment
is rewritten around the new budget, with the numbers kept:

```text
per generation ~ 117 MiB initrd + 14 MiB kernel = ~131 MiB
steady (2)     ~ 265 MiB used, ~246 MiB free   -> nhs guard (200) passes
peak   (2 + 1) ~ 395 MiB, ~115 MiB headroom    -> fits on unguarded paths
overflows only if the initrd grows past ~155 MiB
```

The comment keeps the history: why it was 1, and why the peak is limit + 1.

### 3. Refresh the guard's note

`scripts/check-boot-space.sh`: the comment describing razer's "~150MiB
initrds, 312MiB for 2 generations" is updated to the new figures (the
intent's default). The logic is unchanged. `MIN_FREE_MIB = 200` and the
escalate-to-one-generation fallback stay as the safety net for a future
initrd that outgrows the budget.

## Alternatives rejected

- **Only raise the limit.** 76 MiB of headroom at today's 131 MiB initrd.
  Either way the peak overflows once the initrd passes about 155 MiB, so
  the trim does not move that ceiling. It lowers today's size, which buys
  room to grow: about 38 MiB instead of 24. The initrd was 149 MiB in
  August, so 24 MiB is not enough.
- **Drop NVIDIA from the initrd** (initrd ~46 MiB). Loses early KMS, which
  the intent keeps.
- **Filter only the initrd's copy of the firmware.** NixOS has no hook for
  it. Rewriting `hardware.firmware` with `mkForce` means restating every
  firmware package and reading the option's own value, which recurses.
- **Remove `ucodes_ga10x.bin` too** (55 MiB). It is the Ampere GPU's own
  firmware and is needed.
- **Stronger initrd compression.** It is already zstd -19. The firmware
  blobs barely compress further, so the gain is not worth slower builds.
- **Grow the ESP.** Offline only.

## Risks

- **The GPU fails to start after boot** if a removed file is actually
  needed. The build keeps both `ga10x` files, and `nvidia-smi` plus
  `journalctl -k | grep -i gsp` on the first boot prove it. The previous
  boot entry, which this change is about keeping, is the way back.
- **A future driver renames the firmware.** The glob would then match
  nothing, and `rm` without `-f` fails the build loudly instead of silently
  keeping the Turing files.
- **The first deploy after the change.** The ESP holds one generation now
  (147 MiB used), so the new generation plus the old one fits easily.
  The second entry appears from the next deploy on.
- **Stale plan.** If nixpkgs changes how nvidia firmware reaches the
  initrd, the override stops shrinking it. The first check below catches
  that.

## Verification

- Build razer's initrd: the NVIDIA firmware inside is exactly
  `gsp_ga10x.bin` and `ucodes_ga10x.bin`, and the size is ~117 MiB.
- `nix eval` passes for p620, razer and p510. Only razer's closure changes.
- Build the razer toplevel on p620 (`just test-host razer`).
- Deploy razer (`just deploy-via-p620 razer`), reboot it, and on the new
  boot check that `nvidia-smi` sees the RTX 3080, there are no GSP errors
  in the kernel log, and `systemctl --failed` is clean.
- After the next deploy, `bootctl list` shows two NixOS generations and
  `df /boot` shows at least 200 MiB free.
