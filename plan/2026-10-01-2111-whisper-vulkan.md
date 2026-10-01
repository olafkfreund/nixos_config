---
status: approved
issue: 2111
spec: spec/2026-10-01-2111-whisper-vulkan.md
---

# Plan: run whisper-server on the GPU via Vulkan

## Approved decisions

- New option `features.whisper-server.vulkan` (`bool`, default `false`); only
  p620 sets it. The model stays `base.en`.
- `vulkan = true` uses `pkgs.whisper-cpp-vulkan` (nixpkgs, cached on
  cache.nixos.org, 1.9.2); `false` uses `pkgs.whisper-cpp`, as today. No
  overlay.
- GPU access only when `vulkan = true`: `PrivateDevices = false`,
  `DevicePolicy = "closed"`, `DeviceAllow = [ "char-drm rw" ]`,
  `SupplementaryGroups = [ "render" ]`. No `/dev/kfd` and no ROCm environment.
- Shader cache: `CacheDirectory = "whisper"` and
  `MESA_SHADER_CACHE_DIR=/var/cache/whisper`, set only when `vulkan = true`.
- All other hardening, port 9300 and the tailscale-only firewall are unchanged.
  With `vulkan = false` the rendered unit is identical to today's.

Prototype on p620 (spec): same transcript, total time 1930 ms on CPU, 935 ms on
Vulkan with a cold cache and 338 ms warm. With `PrivateDevices = true` the
Vulkan build logs `ggml_vulkan: No devices found` and silently uses the CPU.

## Steps

1. `modules/services/whisper-server.nix`
   - In the `let` block (line 20), add
     `pkg = if cfg.vulkan then pkgs.whisper-cpp-vulkan else pkgs.whisper-cpp;`.
   - After `openFirewallOnTailscale` (line 45), add the option
     `vulkan = lib.mkOption { type = lib.types.bool; default = false; description = ...; }`.
   - Lines 64 and 70: change `${pkgs.whisper-cpp}` to `${pkg}`.
   - Line 84: change `PrivateDevices = true;` to `PrivateDevices = !cfg.vulkan;`.
   - Line 68: wrap `serviceConfig` as
     `lib.mkMerge [ { ...existing... } (lib.mkIf cfg.vulkan { ... }) ]`,
     where the second set is `DevicePolicy = "closed";`,
     `DeviceAllow = [ "char-drm rw" ];`,
     `SupplementaryGroups = [ "render" ];` and `CacheDirectory = "whisper";`.
   - Add `environment = lib.mkIf cfg.vulkan { MESA_SHADER_CACHE_DIR = "/var/cache/whisper"; };`
     on the service, next to `serviceConfig`.
   - Header comment, lines 1–13: one line saying `vulkan = true` runs it on
     the GPU. No narration comments elsewhere.

   Verify by: `just check-syntax`, then
   `nix eval .#nixosConfigurations.p620.config.systemd.services.whisper-server.serviceConfig.PrivateDevices`
   → `false` (after step 2).

   Traps: no `mkIf cond true` (use `!cfg.vulkan` directly); keep `DynamicUser`,
   `ProtectSystem = "strict"`, `ProtectHome` and `NoNewPrivileges`; do not add
   `/dev/kfd`; keep comments minimal.
2. `hosts/p620/configuration.nix:211-214`: add `vulkan = true;` to
   `features.whisper-server`.

   Verify by: `nix eval .#nixosConfigurations.p620.config.systemd.services.whisper-server.serviceConfig`
   shows `DeviceAllow = [ "char-drm rw" ]`, `SupplementaryGroups = [ "render" ]`,
   `CacheDirectory = "whisper"`, and an `ExecStart` whose store path equals
   `nix eval --raw .#nixosConfigurations.p620.pkgs.whisper-cpp-vulkan`.

   Traps: none.
3. Build: `just test-host p620`. Expect no local compile of whisper-cpp (the
   path substitutes from cache.nixos.org). For razer and p510, compare the
   toplevel `drvPath` against `origin/main`: identical means nothing changed,
   which is stronger than a build and never builds p510.
   Deviation: the plan first said `just test-host razer`; replaced by the
   drvPath comparison during implementation.
   Result: p620 built with 6 derivations (unit files, wrapper), no whisper
   compile; razer and p510 drvPaths are identical to `main`.
4. Deploy p620. This needs your go-ahead at that point. First run
   `read_new("#agents:freundcloud.org.uk")`, post the plan ("p620 deploy:
   whisper-server restart, ~5 min"), then `just quick-deploy p620` with
   `AGENT_BUS_ANNOUNCED=1`, from `main` after merge (deploy recipes refuse a
   branch).

## Tests

- After step 2: `nix eval` of `whisper-server.serviceConfig` on razer gives the
  same result as on `origin/main`. (It's an empty diff; razer doesn't enable
  the service, so this checks only that the module still evaluates.)
- After deploy:
  - `journalctl -u whisper-server -b --no-pager | grep ggml_vulkan` →
    `0 = AMD Radeon RX 7900 XT (RADV NAVI31)`, and no `No devices found`.
  - Generate a speech wav (`espeak-ng` + `ffmpeg -ar 16000 -ac 1`), then
    `curl -F file=@speech.wav http://localhost:9300/inference` → correct
    transcript. Repeat from razer against `http://p620:9300/inference`.
  - `rocm-smi --showmeminfo vram` before and after a request: whisper's VRAM
    use is small, and Ollama still answers on :11434.

## Rollback

Set `vulkan = false` on p620 (or revert the commit) and deploy. The unit goes
back to exactly today's CPU-only unit with `PrivateDevices = true`. For an
immediate rollback, `sudo nixos-rebuild switch --rollback` on p620.
