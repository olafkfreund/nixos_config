# Ollama on p620 + LiteLLM Router for Claude Code

> Date: 2026-05-22
> Status: Design — awaiting implementation approval
> Hosts affected: p620 (server + client), razer (client). p510 untouched.

## 1. Summary

Add a self-hosted local-LLM coding path alongside existing cloud Claude usage.
The user can choose Ollama vs Claude per repository via slash commands; both
work locally (p620 loopback) and remotely from razer (Tailscale) without
changing existing Claude Code behaviour on repos that don't opt in.

**Host choice:** p620's RX 7900 XTX (24 GB VRAM, 960 GB/s memory bandwidth,
gfx1100) is materially better for LLM inference than p510's dual-NVIDIA
(3070 Ti 8 GB + 3060 12 GB, layer-split required, ~3× lower memory
bandwidth). Expected throughput: ~40-60 tok/s on qwen3.6:27b (dense),
~80-100 tok/s on gemma4:26b (MoE, ~3.8B active params).
ROCm stack is already fully wired on p620 (`hosts/p620/nixos/amd.nix`).
Plex/NZBGet stack on p510 stays completely unchanged.

**Components:**

- `services.ollama` on p620 with `ollama-rocm`, dual-tier coding models
  (Qwen3.6-27B dense persistent + Gemma4-26B MoE on-demand) on the single RX 7900 XTX.
- `litellm-router` on p620 — Anthropic-compat proxy that lets Claude Code
  reach Ollama by setting `ANTHROPIC_BASE_URL` per-repo.
- Slash commands `/use-ollama`, `/use-claude`, `/use-default` on p620/razer
  that toggle the per-repo `.claude/settings.json` override.
- `apiKeyHelper` script that auto-selects the right bearer key (router vs
  Anthropic) based on which backend the repo currently points at.

**Non-goals:**

- Local Ollama on razer (router handles remote access via Tailscale).
- Proxying real Anthropic API through LiteLLM (Claude Code talks direct to
  `api.anthropic.com` when no override is set).
- Image/vision input (Qwen2.5-Coder is text-only; cloud Claude handles that).
- Cost-tracking dashboard with persistent storage (in-memory logs only; can
  add postgres later if needed).
- Any changes to p510 (Plex/*arr stack unchanged).

## 2. Architecture

```text
┌─ p620 (RX 7900 XTX 24GB, full GNOME desktop, dev workstation) ──┐
│                                                                  │
│  EXISTING (unchanged):                                          │
│    GNOME desktop, Blender, Chrome, dev tools, syncthing,        │
│    user's daily-driver workload.                                │
│    systemd.targets.sleep.enable = false → never suspends.       │
│                                                                  │
│  NEW:                                                            │
│    ┌──────────────────────────────────────────────────────┐     │
│    │ services.ollama (ollama-rocm)   :11434 (loopback)    │     │
│    │   HSA_OVERRIDE_GFX_VERSION=11.0.0 (already set)      │     │
│    │   qwen3.6:27b (~17GB) persistent, dense, agentic     │     │
│    │   gemma4:26b (~18GB) MoE on-demand, 5m KEEP_ALIVE    │     │
│    │   Each fits single GPU (24GB); evict-then-load on    │     │
│    │   switch since 17+18=35 > 24.                        │     │
│    └──────────────────────────────────────────────────────┘     │
│                                                                  │
│    ┌──────────────────────────────────────────────────────┐     │
│    │ litellm-router   :4000 (loopback + tailnet + LAN)    │     │
│    │   Anthropic /v1/messages → Ollama /api/chat          │     │
│    │   model aliases:                                     │     │
│    │     claude-sonnet-4-6 → qwen3.6:27b                  │     │
│    │     claude-opus-4-6   → gemma4:26b                   │     │
│    │   master key + per-host virtual keys (agenix)        │     │
│    └──────────────────────────────────────────────────────┘     │
│                                                                  │
│    Tailscale Serve (NEW module on p620):                        │
│       https://p620.<tailnet>.ts.net/router → :4000              │
│    Firewall: :4000 on tailscale0 + enp1s0 (LAN) only            │
└──────────────────────────────────────────────────────────────────┘
                            ▲                  ▲
                  loopback (sub-ms)        tailnet (~1-5ms)
                            │                  │
                  ┌─────────┘                  └──────────┐
                  │                                       │
┌─────────────────┴────────────┐         ┌────────────────┴────────────┐
│ p620 (this host as client)   │         │ razer (laptop, mobile)       │
│   Claude Code talks to       │         │   Claude Code                │
│   http://localhost:4000      │         │   apiKeyHelper picks key     │
│   apiKeyHelper:              │         │     ANTHROPIC_BASE_URL set → │
│     URL contains :4000 →     │         │       api-router-razer key   │
│       api-router-p620 key    │         │     URL unset →              │
│     URL unset →              │         │       api-anthropic key      │
│       api-anthropic key      │         │   Slash commands write       │
│   Slash commands write       │         │   https://p620.<TS>/router   │
│   http://localhost:4000      │         │     into .claude/settings    │
└──────────────────────────────┘         └──────────────────────────────┘

p510: unchanged.
```

**Flow when a repo selects Ollama (from p620):**

1. User runs `/use-ollama` in a repo. Helper writes `<repo>/.claude/settings.json`
   with `env.ANTHROPIC_BASE_URL=http://localhost:4000` (auto-selected based on
   `hostname` == "p620") and `model: claude-sonnet-4-6`.
2. Claude Code starts a session. `apiKeyHelper` script sees the URL contains
   `:4000` → emits `cat /run/agenix/api-router-p620`.
3. Claude Code POSTs `/v1/messages` to `http://localhost:4000` (loopback).
4. LiteLLM authenticates the key, maps `claude-sonnet-4-6` →
   `ollama_chat/qwen3.6:27b`, forwards to
   `http://127.0.0.1:11434/api/chat`.
5. Ollama loads the model on RX 7900 XTX (~3s cold-load), streams response back.
   Subsequent requests are ~50-80 tok/s.

**Flow when a repo selects Ollama (from razer, over Tailscale):**

Same as above but the URL is `https://p620.<tailnet>.ts.net/router` and the
key is `api-router-razer`. Tailscale-serve on p620 maps the `/router` path to
`localhost:4000`.

**Flow when a repo uses Claude (default):**

No `.claude/settings.json` override. `apiKeyHelper` sees no router URL → emits
`api-anthropic`. Request goes direct to `api.anthropic.com` (existing
behaviour, unchanged on both p620 and razer).

## 3. Module structure

```text
modules/
├── services/
│   ├── ollama.nix              ← NEW (ollama-rocm + qwen3.6/gemma4 lifecycle)
│   └── litellm-router.nix      ← NEW (Anthropic-compat proxy)
├── ai/providers/
│   ├── ollama.nix              ← NEW (parallel to anthropic.nix)
│   └── default.nix             ← MODIFY (widen defaultProvider enum to
│                                  include "ollama" — only needed if you also
│                                  want ai-cli / aichat to target ollama;
│                                  skip if Claude Code is the only consumer)
├── programs/
│   ├── claude-router-cli.nix   ← NEW (slash commands + helper script)
│   └── claude-code-managed.nix ← MODIFY (add apiKeyHelper default)
└── secrets/
    └── api-keys.nix            ← MODIFY (add router master + virtual keys)

secrets/
├── litellm-master-key.age      ← NEW (master key; recipient: p620)
├── api-router-p620.age         ← NEW (same plaintext; recipient: p620)
├── api-router-razer.age        ← NEW (same plaintext; recipient: razer)
└── secrets.nix                 ← MODIFY (declare new secrets, set recipients)

hosts/p620/configuration.nix    ← MODIFY (enable ollama-server + litellm-router
                                   + claude-router-cli)
hosts/p620/nixos/tailscale-serve.nix ← NEW (mirror of p510's pattern, adds /router)
hosts/razer/configuration.nix   ← MODIFY (enable claude-router-cli only)

# p510 — NOT modified. Plex/*arr stack stays as-is.
```

## 4. Ollama service (`modules/services/ollama.nix`)

### Ollama module options

```nix
options.features.ollama-server = {
  enable = mkEnableOption "Ollama coding model server";
  package = mkOption {
    type = types.package;
    default = pkgs.ollama-rocm;
    description = "Ollama package. Use ollama-rocm for AMD GPUs, ollama-cuda for NVIDIA.";
  };
  persistentModels = mkOption {
    type = types.listOf types.str;
    default = [ "qwen3.6:27b" ];
    description = "Models pulled at activation and used as the default coding model.";
  };
  onDemandModels = mkOption {
    type = types.listOf types.str;
    default = [ "gemma4:26b" ];
    description = "Models pulled at activation, loaded on first request, evicted after KEEP_ALIVE.";
  };
  keepAlive = mkOption {
    type = types.str;
    default = "5m";
    description = ''
      Auto-unload models after this idle time. On p620 (workstation), keep
      this low so the GPU is freed for desktop work (Blender, games, etc.)
      when not actively coding.
    '';
  };
};
```

### Configuration

- `services.ollama.host = "127.0.0.1"` — loopback only.
- `services.ollama.port = 11434`.
- `services.ollama.loadModels = persistentModels ++ onDemandModels` —
  post-activation oneshot (does not block `nixos-rebuild switch`).
- Environment variables:
  - `HSA_OVERRIDE_GFX_VERSION=11.0.0` (already set system-wide in
    `hosts/p620/nixos/amd.nix:124`; restated here for unit-local clarity)
  - `ROCR_VISIBLE_DEVICES=0` (only the discrete RX 7900 XTX; no iGPU
    fall-through)
  - `OLLAMA_KEEP_ALIVE=5m` (not -1 — RX 7900 XTX is the user's daily-driver
    GPU; auto-unload when idle so Blender/games/video work isn't blocked)
  - `OLLAMA_NUM_PARALLEL=1` (one request at a time → predictable VRAM)
  - `OLLAMA_MAX_LOADED_MODELS=1` (only one model resident at a time — both
    qwen3.6:27b and gemma4:26b fit individually but the sum ~35GB exceeds
    the 24GB GPU.
    Setting this to 2 would invite mid-inference OOM eviction; 1 forces
    clean evict-then-load semantics on model switch with predictable
    cold-load timing.)
  - `OLLAMA_FLASH_ATTENTION=1` (works on RDNA3)
- Systemd hardening:
  - `OOMScoreAdjust=200` (the user's desktop apps should win OOM tiebreaks —
    we'd rather lose Ollama than Chrome/IDE)
  - `Nice=10` (lower priority than interactive desktop)
  - `IOSchedulingClass=best-effort, Priority=5`

### GPU strategy (single GPU, no split needed)

| Model | VRAM | Fits | Notes |
|---|---|---|---|
| qwen3.6:27b (dense) | ~17 GB | Yes (24 GB GPU, 7 GB headroom) | Persistent default. ~40-60 tok/s on RX 7900 XTX. Strong tool-calling (Qwen RL-trained on 1M agentic envs) — best for Claude Code's agent loop. |
| gemma4:26b (MoE, ~3.8B active) | ~18 GB | Yes (24 GB GPU, 6 GB headroom) | On-demand. ~80-100 tok/s thanks to MoE — best for raw code-gen speed. |
| Both simultaneously | ~35 GB | NO (exceeds 24 GB) | Evict-then-load on switch. With OLLAMA_MAX_LOADED_MODELS=1 this is deterministic (~6-10s cold-load each direction). |

`OLLAMA_MAX_LOADED_MODELS=2` allows fast switching IF VRAM permits; here it
doesn't, so practical behaviour is "one at a time, evict-and-load on switch".
Cold-load is ~5s for qwen3.6:27b, ~6s for gemma4:26b from disk cache. From
cold disk: 30-60s first ever load (then cached by the OS page cache).

### Bootstrap

First deploy pulls ~35 GB (qwen3.6:27b + gemma4:26b) into the configured
`modelsDir` (default `/mnt/data/ollama/models` on p620). `services.ollama.loadModels` runs as a
post-activation systemd oneshot — `nixos-rebuild switch` returns immediately,
model download runs in background. Estimate 10-20 min on gigabit. Idempotent:
subsequent activations skip already-pulled models.

Monitoring: `systemctl status ollama-model-loader.service`.

## 5. LiteLLM router (`modules/services/litellm-router.nix`)

### LiteLLM module options

```nix
options.features.litellm-router = {
  enable = mkEnableOption "LiteLLM proxy for Anthropic-compat Ollama access";
  port = mkOption { type = types.port; default = 4000; };
  listenLanInterface = mkOption {
    type = types.str;
    default = "enp1s0";
    description = ''
      LAN interface to open the port on (in addition to tailscale0 and
      loopback). Confirm via `ip link` before deploying.
    '';
  };
};
```

### Config file (`litellm-config.yaml`, generated by `pkgs.writeText`)

```yaml
model_list:
  # Aliases Claude Code knows by name → Ollama models behind them.
  - model_name: claude-sonnet-4-6
    litellm_params:
      model: ollama_chat/qwen3.6:27b
      api_base: http://127.0.0.1:11434

  - model_name: claude-opus-4-6
    litellm_params:
      model: ollama_chat/gemma4:26b
      api_base: http://127.0.0.1:11434

  # Native names for ai-cli / aichat / direct OpenAI-compat clients
  - model_name: qwen3.6
    litellm_params:
      model: ollama_chat/qwen3.6:27b
      api_base: http://127.0.0.1:11434

  - model_name: gemma4
    litellm_params:
      model: ollama_chat/gemma4:26b
      api_base: http://127.0.0.1:11434

general_settings:
  master_key: os.environ/LITELLM_MASTER_KEY

litellm_settings:
  drop_params: true       # silently drop Anthropic-only params (cache_control etc.)
  set_verbose: false
```

### Systemd unit

- Runs as `DynamicUser`, `ProtectSystem=strict`, `ProtectHome`, `PrivateTmp`,
  `NoNewPrivileges`, `RestrictSUIDSGID`.
- Memory cap 2GB.
- `ExecStart`: shell wrapper that reads `LITELLM_MASTER_KEY` from the
  agenix-decrypted file path, exports it, then exec's `litellm --config ...`.
- `Restart=on-failure`, `RestartSec=5`.
- `After=ollama.service`, `Wants=ollama.service`.

### Firewall

```nix
networking.firewall.interfaces = {
  "tailscale0".allowedTCPPorts = [ 4000 ];
  ${cfg.listenLanInterface}.allowedTCPPorts = [ 4000 ];   # enp1s0 on p620
};
```

Port 4000 NOT in global `allowedTCPPorts`; reachable only on the listed
interfaces (loopback is always implicit). LiteLLM binds the service to
`0.0.0.0:4000`; firewall does the access control. Ollama itself stays
on loopback-only `127.0.0.1:11434` (never reachable from any network
interface).

### Tailscale serve (NEW module on p620)

p620 does not currently have a tailscale-serve config. Create
`hosts/p620/nixos/tailscale-serve.nix` mirroring the p510 pattern but with
only the `/router` path:

```nix
{ pkgs, ... }: {
  systemd.services.tailscale-serve = {
    description = "Tailscale Serve — Expose LiteLLM Router";
    after = [ "tailscaled.service" "network-online.target" "litellm-router.service" ];
    wants = [ "network-online.target" "litellm-router.service" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "tailscale-serve-start" ''
        until ${pkgs.tailscale}/bin/tailscale status &>/dev/null; do
          sleep 2
        done
        ${pkgs.tailscale}/bin/tailscale serve --bg --https=443 \
          --set-path=/router http://localhost:4000
      '';
    };
  };
}
```

Result: `https://p620.<tailnet>.ts.net/router` reachable from any tailnet peer.

### Secrets

- `litellm-master-key.age` — long random string (64+ chars,
  `openssl rand -base64 48`). Recipient: p620 only.
- `api-router-p620.age` — same plaintext as master. Recipient: p620 (for
  `apiKeyHelper` reading on p620 itself, when it's both server and client).
- `api-router-razer.age` — same plaintext as master. Recipient: razer.

**v1 deployment mechanism:** the master plaintext is identical across all
three `.age` files — they differ only in which host's age public key encrypts
them (declared in `secrets/secrets.nix`). The router on p620 reads
`litellm-master-key.age` to validate; clients on p620 and razer read their
respective `api-router-<host>.age` to authenticate. The plaintext matches; the
recipients don't. This keeps the agenix access-control model intact while
sharing the key value. v2 can split with proper LiteLLM virtual keys via
`/key/generate` API.

**Initial provisioning / rotation runbook** (run once on a workstation with
the agenix CLI and the three recipient keys configured in `secrets.nix`):

```bash
# Generate the value once
KEY="$(openssl rand -base64 48)"

# Encrypt the SAME plaintext under each file's recipient set.
# (Each call to `agenix -e` re-derives recipients from secrets.nix.)
cd secrets/
echo "$KEY" | agenix -e litellm-master-key.age   # recipient: p620
echo "$KEY" | agenix -e api-router-p620.age       # recipient: p620
echo "$KEY" | agenix -e api-router-razer.age      # recipient: razer

unset KEY        # never write it to history or files
```

To rotate: repeat the same three commands with a freshly generated `KEY`.
Then `nh os switch` on p620 (router will read new master) and `nh os switch`
on razer (client picks up new bearer). No service downtime if rotated in that
order (router accepts requests with old key until restart, client switches
key only after redeploy).

## 6. Claude Code client integration

### `modules/programs/claude-router-cli.nix`

Installs:

1. **`/run/current-system/sw/bin/claude-router`** — helper script (bash):
   - `claude-router use-ollama` — writes `<repo>/.claude/settings.json` with
     `env.ANTHROPIC_BASE_URL` set based on `hostname`:
     - On `p620` → `http://localhost:4000` (loopback, sub-ms latency)
     - On `razer` → `https://p620.<tailnet>.ts.net/router`
     - Plus `model: claude-sonnet-4-6`.
   - `claude-router use-claude` — removes `.claude/settings.json` (or empties
     it to `{}`).
   - `claude-router use-default` — same as `use-claude` for v1.
   - `claude-router status` — read the file, print which backend the current
     repo uses.
   - All commands operate on `git rev-parse --show-toplevel || pwd`.

2. **Slash command files** under `<user>/.claude/commands/`:
   - `use-ollama.md` → invokes `claude-router use-ollama`
   - `use-claude.md` → invokes `claude-router use-claude`
   - `use-default.md` → invokes `claude-router use-default`
   - Installed declaratively via Home Manager (matches existing pattern).

3. **`/run/current-system/sw/bin/claude-router-key`** — apiKeyHelper script:

   ```bash
   #!/usr/bin/env bash
   # Match :4000 or p620 router path — avoids false positives if other p620
   # URLs (e.g. binary cache :5000) ever leak into ANTHROPIC_BASE_URL.
   if [[ "$ANTHROPIC_BASE_URL" == *:4000* \
      || "$ANTHROPIC_BASE_URL" == *p620.*ts.net/router* ]]; then
     cat /run/agenix/api-router-$(hostname)
   else
     cat /run/agenix/api-anthropic
   fi
   ```

### `modules/programs/claude-code-managed.nix` modification

Add a default `apiKeyHelper` to the managed settings:

```nix
settings = lib.mkDefault {
  apiKeyHelper = "/run/current-system/sw/bin/claude-router-key";
};
```

Applies on hosts where `modules.programs.claude-code-managed.enable = true`
(p620 and razer). User can override per-session via the standard Claude Code
settings hierarchy.

## 7. Risks & mitigations

| # | Risk | Likelihood | Impact | Mitigation |
|---|------|------------|--------|------------|
| 1 | First deploy hangs pulling 30GB models | M | Slow first switch, doesn't block | Post-activation oneshot; status visible via `systemctl` |
| 2 | Ollama competes with desktop GPU work (Blender, games, video editing) | M | Stutter/slowdown for desktop or Ollama | `OLLAMA_KEEP_ALIVE=5m` auto-unloads when idle; manual `ollama stop` for heavy GPU work; `Nice=10` + `OOMScoreAdjust=200` make desktop apps preempt |
| 3 | LiteLLM crashes / OOM | L | Router down; repos using Ollama need `/use-claude` to switch back | `Restart=on-failure`; 2GB memory cap; `/use-claude` escape hatch |
| 4 | Qwen tool-use produces malformed calls | M | Specific Claude Code request errors | Per-turn retry; `/use-claude` for affected workflows |
| 5 | Anthropic prompt cache savings lost on Ollama path | Certain | More tokens reprocessed per request | Inherent limitation; mitigated by RX 7900 XTX speed (~40-60 tok/s on qwen3.6:27b dense, ~80-100 tok/s on gemma4:26b MoE); document |
| 6 | Tailscale outage / razer offline | M | Razer can't reach router | `apiKeyHelper` falls through to `api-anthropic` automatically |
| 7 | Master key compromise | L | Compute abuse on Ollama | Agenix-encrypted; rotate by re-encrypt + redeploy (~3min) |
| 8 | ROCm kernel/driver regression on nixpkgs bump | L (RDNA3 well-supported in 2026) | Ollama startup fails | `just test-host p620` in CI catches; standard NixOS rollback via `--rollback`; existing `services.ollama.package = pkgs.ollama-rocm` is the only knob to pin |
| 9 | Ollama port 11434 accidentally exposed | L | Direct unauth model access | Module enforces `host="127.0.0.1"`; firewall doesn't open 11434 anywhere |
| 10 | p620 powered off when razer wants remote access | M | Razer falls back to cloud Claude | `apiKeyHelper` automatic fallback to api-anthropic; `systemd.targets.sleep.enable = false` (already set in `hosts/p620/nixos/power.nix`) keeps p620 awake when on AC; for explicit Wake-on-LAN, see §13 open questions |

## 8. p510 / Plex / NZBGet impact

**None.** This design touches p620 and razer only. Plex, NZBGet, Sonarr,
Radarr, Lidarr, Prowlarr, Transmission, NFS, Recyclarr, Tautulli on p510 are
not modified. No new firewall rules, services, ports, or packages on p510.

## 9. p620 desktop-work impact (the new contention concern)

| Scenario | What happens | Mitigation |
|---|---|---|
| Coding with qwen3.6:27b loaded, then open Blender | Blender VRAM alloc succeeds (7GB headroom on 24GB GPU); slight contention for compute cycles when Ollama is mid-inference | `Nice=10` on ollama service; manual `ollama stop` if Blender is heavy |
| Playing a game, gemma4:26b is loaded | Game VRAM alloc may struggle (6GB headroom only); game stutters or fails | `OLLAMA_KEEP_ALIVE=5m` — if you haven't queried Ollama in 5 min, model auto-unloads, GPU is free. For sure-thing: `sudo systemctl stop ollama.service` (cleanest one-liner — releases VRAM immediately, service restarts on next request) |
| Video editing with ML upscaling | Same VRAM contention as gaming | Same mitigation |
| Browsing / IDE only | Zero contention (these use <1GB VRAM) | No action needed |

The contention is real but bounded: either model leaves ~6-7GB headroom for
other GPU work, which covers light desktop scenarios but not gaming or heavy
3D. Treat it like "I'm queueing a model, don't expect to game right now" —
or stop ollama before gaming.

## 10. Rollback procedure

Single-line rollback at any layer:

```nix
# hosts/p620/configuration.nix
features.ollama-server.enable    = lib.mkForce false;
features.litellm-router.enable   = lib.mkForce false;
modules.programs.claude-router-cli.enable = lib.mkForce false;

# hosts/razer/configuration.nix
modules.programs.claude-router-cli.enable = lib.mkForce false;
```

Then `nh os switch` (or `nhs p620`, `nhs razer`). All new services stopped.
Existing Claude Code workflows unchanged because per-repo `.claude/settings.json`
files just point at an unreachable URL → request fails → user runs
`/use-claude` or deletes the file.

`nixos-rebuild switch --rollback` works as always. Ollama state in
`/var/lib/ollama` is preserved across rollback (re-enable later → models still
there). LiteLLM has no persistent state.

## 11. Phased rollout

| Phase | PR | Scope | Verify before next phase |
|-------|----|-------|--------------------------|
| 1 | `feat(p620): ollama-rocm with dual-tier coding models` | `modules/services/ollama.nix`, p620 config flag, model pull | `curl http://localhost:11434/api/tags` lists both models; `ollama run qwen2.5-coder:14b "hello"` works; `rocm-smi` shows GPU in use during inference; desktop work (open Blender briefly) doesn't error |
| 2 | `feat(p620): litellm-router + tailscale-serve /router` | `modules/services/litellm-router.nix`, agenix master key secret, **NEW `hosts/p620/nixos/tailscale-serve.nix`**, p620 config flag, p620 firewall additions | `curl -H "Authorization: Bearer $KEY" http://localhost:4000/v1/messages -d '...'` returns response; same via `https://p620.<tailnet>.ts.net/router` from razer (Tailscale-remote) |
| 3 | `feat(p620,razer): claude-router-cli + apiKeyHelper` | `modules/programs/claude-router-cli.nix`, `modules/programs/claude-code-managed.nix` apiKeyHelper default, agenix virtual key secrets, p620/razer config flags, slash commands installed | In a scratch repo on p620, `/use-ollama` writes settings; `claude "hello"` shows Qwen response in `journalctl -u litellm-router -f`; `/use-claude` removes override; subsequent `claude "hello"` hits real Anthropic |

Each phase is a self-contained PR. Rollback from Phase 3 → router + Ollama
still work for direct API testing. Rollback from Phase 2 → Ollama works via
`ollama run` CLI. Rollback from Phase 1 → no change to baseline.

## 12. Acceptance criteria

The plan is "done" when all of these are true:

- [ ] **Pre-Phase-1 baseline captured**: `rocm-smi --showmemuse --showuse`
      snapshot saved before any deploy.
- [ ] **Negative firewall test**: from a non-tailnet, non-LAN source
      (e.g. host outside the subnet over WireGuard or a remote SSH jump),
      `curl http://<p620-public-ip>:4000` connection-refuses or times out.
- [ ] On p620, in a fresh repo, `/use-ollama` writes `.claude/settings.json`,
      and `claude "say hi"` shows a response from qwen3.6:27b visible in
      LiteLLM access logs (`journalctl -u litellm-router -f`).
- [ ] On p620, in the same repo, `/use-claude` removes the override, and
      `claude "say hi"` shows a response from real Claude (no LiteLLM log
      entry; bills the Anthropic API key).
- [ ] From razer **via Tailscale outside LAN** (phone tether or remote
      network), `/use-ollama` works.
- [ ] `rocm-smi` shows the RX 7900 XTX hitting ~95% utilisation during
      inference; idle VRAM use returns to baseline within 6 minutes of last
      query.
- [ ] First request to `claude-opus-4-6` (the gemma4:26b alias) returns within
      ~30s including cold model load (with VRAM eviction of qwen3.6:27b
      first); subsequent requests are fast (~80-100 tok/s sustained thanks
      to MoE).
- [ ] After 6 minutes idle on any model, `rocm-smi` shows VRAM freed.
- [ ] `ss -tlnp | grep 11434` shows Ollama bound to `127.0.0.1:11434` only
      (NOT `0.0.0.0:11434`); confirms the §4 loopback invariant.
- [ ] `ss -tlnp | grep 4000` shows LiteLLM bound to `0.0.0.0:4000`, but
      `nmap -p 4000 <p620-public-ip>` from an outside host shows filtered
      (firewall scoping working).
- [ ] Smoke test: open Blender on p620 after `ollama stop`; Eevee/Cycles
      preview renders normally with full GPU.
- [ ] `nh os switch --rollback` cleanly disables the lot.
- [ ] `just test-host p620 && just test-host razer` pass on the feature
      branch before each PR merge.

## 13. Open questions / explicit non-decisions

- **Wake-on-LAN for p620** when fully powered off (vs current state of
  "never sleeps but can be manually shut down"): deferred. If you want razer
  to remotely wake p620 from full power-off, add WoL config to amd.nix later.
- **Cost-tracking dashboard with persistent storage**: deferred. Add postgres
  - LiteLLM `/ui` later if usage metrics become interesting.
- **Per-request model override from Claude Code**: deferred. Currently the
  per-repo settings file is the only way to switch model. Future: add a
  `/model claude-opus-4-6` slash command that updates the settings inline.
- **Anthropic prompt cache for Ollama**: not possible (Ollama has no
  equivalent). Document the latency/cost tradeoff in repo README.
- **Multiple users / team keys**: out of scope. Single user (olafkfreund).
- **ROCm version pinning**: not needed unless a regression appears. Current
  nixpkgs ROCm + ollama-rocm support gfx1100 natively.

## 14. References

- LiteLLM proxy docs: <https://docs.litellm.ai/docs/proxy/quick_start>
- Ollama NixOS module: <https://search.nixos.org/options?query=services.ollama>
- Claude Code settings precedence: <https://code.claude.com/docs/en/settings>
- Qwen3.6-27B model card: <https://huggingface.co/Qwen/Qwen3.6-27B>
- Gemma 4 family: <https://deepmind.google/models/gemma/gemma-4/>
- Ollama qwen3.6 tags: <https://ollama.com/library/qwen3.6/tags>
- Ollama gemma4 tags: <https://ollama.com/library/gemma4/tags>
- AMD ROCm gfx1100 (RDNA3) support: <https://rocm.docs.amd.com/projects/install-on-linux/en/latest/reference/system-requirements.html>
- This repo's pattern conventions: `docs/PATTERNS.md`,
  `docs/NIXOS-ANTI-PATTERNS.md`
