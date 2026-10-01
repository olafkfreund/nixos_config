---
status: draft
issue: 2111
intent: intent/2026-10-01-2111-whisper-vulkan.md
---

# Spec: run whisper-server on the GPU via Vulkan

## Design

The intent's open questions were approved with their proposed answers: GPU
support is an opt-in option, enabled only on p620, and the model stays
`base.en`.

All changes are in `modules/services/whisper-server.nix`, plus one line in
`hosts/p620/configuration.nix`.

1. **New option** `features.whisper-server.vulkan` (`bool`, default `false`).
   It selects the package:
   `pkg = if cfg.vulkan then pkgs.whisper-cpp-vulkan else pkgs.whisper-cpp;`
   That package replaces `pkgs.whisper-cpp` in both `preStart` (model download)
   and `ExecStart`. `whisper-cpp-vulkan` is a nixpkgs attribute already on
   cache.nixos.org (1.9.2, the same version as today's CPU build), so there is
   no overlay and no local compile.
2. **Device access, only when `vulkan` is on.** Replace `PrivateDevices = true`
   with:
   - `PrivateDevices = false`
   - `DevicePolicy = "closed"` (the device cgroup still denies everything not
     listed, plus the standard pseudo-devices)
   - `DeviceAllow = [ "char-drm rw" ]` (DRM nodes only, so `/dev/dri/*`; no
     `/dev/kfd`, because Vulkan/RADV does not use ROCm's compute device)
   - `SupplementaryGroups = [ "render" ]` (the render node's group)

   `char-drm` is used instead of `/dev/dri/renderD128` because the node
   number is not guaranteed stable across boots or GPU changes.
3. **Shader cache.** Add `CacheDirectory = "whisper"` and
   `MESA_SHADER_CACHE_DIR=/var/cache/whisper`. A DynamicUser has no `$HOME`,
   so without this Mesa cannot keep its compiled shaders, and every restart
   pays the first-run compile again.
4. **Everything else stays as it is**: `DynamicUser`,
   `ProtectSystem = "strict"`, `ProtectHome`, `NoNewPrivileges`, the syscall
   filter, `MemoryMax = 1G`, `TasksMax`, port 9300 and the tailscale-only
   firewall. When `vulkan = false` the unit renders the same as it does today.
5. **p620** sets `features.whisper-server.vulkan = true;`.

Implementation: `lib.mkIf cfg.vulkan` / `lib.mkMerge` inside `serviceConfig`,
with `PrivateDevices = !cfg.vulkan;` as a plain boolean (no `mkIf cond true`).
The module header comment is updated to say the server can run on the GPU.

### Prototype evidence (p620, 2026-10-01)

Transient `systemd-run` units with the module's hardening, `base.en`, and a
9.7 s speech clip. The transcript was identical in every run:

| Build / sandbox | Result | Total time |
| --- | --- | --- |
| CPU build, current `PrivateDevices = true` | CPU | 1930 ms |
| Vulkan build, `PrivateDevices = true` | `ggml_vulkan: No devices found`, falls back to CPU | n/a |
| Vulkan build, design above, cold shader cache | RX 7900 XTX (RADV NAVI31) | 935 ms |
| Vulkan build, design above, warm cache | RX 7900 XTX | 338 ms (encode 15 ms vs 1053 ms) |

## Alternatives rejected

- **Swap the package unconditionally.** With `PrivateDevices = true` it
  silently falls back to CPU (shown above). Without that setting, a host with
  no usable GPU would also lose the device lockdown for nothing.
- **ROCm/HIP whisper build** (`rocmSupport`). It isn't cached, so it would
  compile locally, and it needs `/dev/kfd` plus ROCm environment handling. It
  would also share the ROCm runtime with Ollama. RADV Vulkan is cached and
  enough for `base.en`.
- **`DeviceAllow = "/dev/dri/renderD128"`.** Tighter, but it breaks quietly if
  the node is renumbered.
- **Lemonade (nix-amd-ai) as the speech-to-text server.** It would change the
  API on port 9300 and the clients, and brings a large closure. That is out of
  scope.
- **Bigger model now.** Deferred, per the intent.

## Risks

- **VRAM contention with Ollama** on p620: `base.en` on Vulkan is a few hundred
  MB at most, against 24 GB. That's low risk, but it's checked at verification.
- **Silent CPU fallback.** If device access is wrong, whisper.cpp falls back to
  the CPU with no error, so a "working" service proves nothing. Verification
  must check the journal for the device line.
- **GPU reset or a driver hang.** p620 has an open GPU PCIe fatal-reset issue
  (#1820). A whisper request is now one more GPU client. `Restart =
  "on-failure"` covers a crash, and the CPU path is one option flip away.
- **Deploy.** It only restarts `whisper-server` on p620. razer and p510 don't
  change (the option defaults to false, and p510 doesn't enable the service).

## Verification

1. `nix eval` of the unit: with `vulkan = true` it has `PrivateDevices=false`,
   `DeviceAllow=char-drm rw`, `SupplementaryGroups=render` and
   `whisper-cpp-vulkan` in `ExecStart`. razer and p510 evaluate unchanged.
2. `just test-host p620` builds without a local compile of whisper-cpp.
3. After deploy (announced on the agent bus), `journalctl -u whisper-server`
   shows `ggml_vulkan: 0 = AMD Radeon RX 7900 XT` and no `No devices found`.
4. A POST of a speech wav to `http://p620:9300/inference` returns the expected
   transcript, both locally and from razer over the tailnet.
5. `rocm-smi --showmeminfo vram` before and after a request: whisper's VRAM
   use is small, and Ollama is unaffected.
