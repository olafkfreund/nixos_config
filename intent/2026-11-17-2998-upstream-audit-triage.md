---
status: draft
issue: 2998
author: olafkfreund
---

# Intent: Triage the 2026-11-17 NixOS upstream audit (15 Watch items)

## Problem

Issue 2998 is the nightly upstream audit. It lists 15 Watch items that matched an inventory
keyword but were not checked against what p620, razer and p510 really run. Someone has to
decide which ones touch our config. The rest should be closed so the next audit starts clean.
Upstream links are `https://github.com/NixOS/nixpkgs/issues/<number>` for each number below.

I checked each item against the repo (nixpkgs lock `d5cc683399`, release 26.11). I did not
re-read the upstream threads for the status of a fix. That is left as an open question below.

## Proposed outcome

Verdict: triage-only. No code change is proposed yet. Most items do not touch us, but several
are exposed or unproven (see "Exposed or unproven" below), so closing 2998 waits on the open questions.

Not in our config, recommend closing (nothing installed or enabled):

- 588860 `nixos-generate-config` Docker overlay mounts: we do not use generated configs
  for the hosts. Hardware files are hand-kept per host.
- 588533 zellij `terminal`: zellij is in no package list. `flake.nix:281`,
  `Users/olafkfreund/profile.nix:204` and `home/development/default.nix:54` only mention it in comments.
- 588493 ettercap: not installed anywhere. The NFS server hits (`hosts/p620/configuration.nix:407`,
  `hosts/razer/configuration.nix:230`) are kernel nfsd, not ettercap.
- 588377 `gnomeExtensions.copyous`: not in `home/desktop/gnome/extensions.nix` (lines 128 onward).
- 587751 `discord.withVencord`: we install `pkgs.vesktop` (`home/desktop/com.nix:13`), not
  `withVencord`. Different package.
- 587387 `linux_zen`: no host uses it. Kernels are `linuxPackages_latest` (p620, razer) and
  `linuxPackages_6_18` (p510), see each `hosts/<host>/nixos/boot.nix`.
- 555161 lima: not installed. `virtiofsd` hits are in `modules/virt/virt.nix`, unrelated.
- 224332 NVIDIA Wayland acceleration libraries: a 2023 usage question. Our NVIDIA hosts set
  `hardware.graphics` in `hosts/p510/nixos/nvidia.nix` and `hosts/razer/nixos/nvidia.nix`.

Exposed or unproven (Codex review, checked against the repo; none is settled):

- 589114 t3code voice input: `t3-code` is the same package as `t3code`. The Nixarchy catalog maps
  `t3-code` to `attr = "t3code"` (not re-read here; Codex cites the pinned catalog) and p620 enables
  it (`hosts/p620/nixarchy/apps.nix:68`, confirmed). So p620 is exposed. Our external dictation
  service (`home/applications/voice-input.nix`, p620:9300) does not fix a speech-library failure
  inside the packaged app. Reproduction and remedy are open.
- 554125 `linux_7_2.nvidia_x11` build failure: razer uses `linuxPackages_latest` with
  `nvidiaPackages.latest` (`hosts/razer/nixos/nvidia.nix:27`, `hosts/razer/nixos/boot.nix:83`).
  The earlier "only that exact pair" claim is dropped. Codex says the pin already resolves
  `linux_latest` to 7.3 and a newer driver, and the upstream thread says that mix builds. I did
  not check the resolved versions; unverified. Decide from resolved versions, not from 7.2. p510
  pins 6.18, p620 is AMD.
- 136920 NVIDIA in Docker and podman: p510 and razer enable `nvidia-container-toolkit`
  (`hosts/p510/nixos/nvidia.nix:149`). `hosts/p510/nixos/resilience.nix:55-127` only keeps docker and
  podman running when the CDI generator fails; its own comment says GPU containers then run
  degraded. That is runtime availability, not working GPU access. Needs evidence that a CDI
  GPU container starts today.
- 504370 gnome-keyring fails to unlock: `overlays/upstream-fixes.nix:51-57` patches 50.0 for an
  OpenSession error and overlapping unlock requests (#2746, #2750). The upstream report is
  version 48.0, intermittent login unlock, with a later SDDM repro. Possibly mitigated; the
  link to the same cause is unverified. Ask whether unlock is reliable on each host's real login path.
- 587975 tailscale waits for `network-online`: p620 (`hosts/p620/configuration.nix:102`), razer
  (`hosts/razer/configuration.nix:92`) and p510 (`hosts/p510/configuration.nix:84`) run
  `services.tailscale`. The boot delay is unmeasured: desktop networking disables the
  NetworkManager wait unit (`modules/common/networking.nix:97`) and p510 disables both wait units
  (`hosts/p510/configuration.nix:419-420`). Delay unknown until the dependency chain is timed.

Needs watching:

- 588180 NVIDIA resume fails: razer sets `powerManagement.enable = true` and
  `NVreg_PreserveVideoMemoryAllocations=1` (`hosts/razer/nixos/nvidia.nix:9,104`). It
  suspends, so this could bite. Upstream shows an Xorg crash on driver 595.71.05; razer uses a newer
  driver and defaults to Omarchy, so a clean Omarchy suspend would not settle an Xorg-only report.
  Compare driver and session first, then test. Do not change config yet.
- 587731 mutter core dump since 51.0 with NVIDIA: mutter ships wherever GNOME is on.
  `hosts/templates/desktop.nix:43` enables GNOME with `mkDefault` on every desktop host, and
  the default session is Omarchy. Only a GNOME login on razer or p510 (NVIDIA) is exposed.
  Upstream calls the NVIDIA link tentative and a later comment names a patch. Ask whether the fix
  is hardware-specific before excluding AMD p620. No change unless someone logs into GNOME there.

## Affected users and systems

- razer (laptop, NVIDIA Optimus): 588180, 587731, 554125, 504370, 587975, 136920.
- p510 (workstation, NVIDIA): 136920, 587731, 587975, 504370.
- p620 (AMD): 589114 (exposed), 587975, 504370.
- No change to any module, host or doc. The output is a closing comment on issue 2998.

## Constraints

- Triage only: no code, no build, no deploy. p510 is never built or deployed without asking.
- Findings come from grepping the repo, not from evaluating each host closure. A package could
  arrive through a transitive dependency we did not grep.
- The audit script keeps the reason "keyword matched" for every item. Fixing its inventory
  matching is out of scope here.

## Open questions

1. Close issue 2998 now, or keep it open until the exposed items are settled? The workflow
   (`.github/workflows/nixos-issue-audit.yml:69`) only reuses an open rolling issue, so closing it
   makes the next run create a new one. Cross-run dedup (line 93) covers only Critical and
   Regression items. A watch issue would not stop repeats. Are repeated Watch entries acceptable
   while automation changes stay out of scope?
2. Test a suspend and resume on razer to settle 588180? Recommend yes, a manual test
   at the owner's convenience. It costs one suspend and needs no deploy.
3. Should the audit script skip packages not in any host closure, to cut false Watch items?
   Recommend a separate issue, since this one is triage only.
4. Upstream state (fix merged or not) was not re-checked for 588180, 587731 and 587975.
   Recommend checking them in the same pass as the razer suspend test before closing.
5. Does a CDI GPU container work on p510 and razer today (existing evidence, no deploy)?
6. Does gnome-keyring unlock reliably on each host's real login path?
7. Reproduce 589114 on p620? What do the resolved kernel and driver versions say for 554125?
