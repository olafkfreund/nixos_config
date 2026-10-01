---
status: approved
issue: 2111
author: olafkfreund
---

# Intent: run whisper-server on the GPU via Vulkan

## Problem

`features.whisper-server` (`modules/services/whisper-server.nix`) serves
speech-to-text for the voice-input clients on p620 and razer. It runs the
CPU-only `pkgs.whisper-cpp` with four threads, so every dictation burns CPU on
p620 while its RX 7900 XTX does nothing for this workload. Latency on a
hold-to-talk hotkey is directly felt by the user.

The service is also hardened with `PrivateDevices = true`, which hides
`/dev/dri`, so a GPU build cannot simply be swapped in.

## Proposed outcome

whisper-server on p620 transcribes on the 7900 XTX through Vulkan (RADV). The
HTTP API on port 9300 is unchanged, so voice-input clients on p620 and razer
need no change. Transcription is at least as fast as today and CPU use per
request drops.

## Affected users and systems

- p620: the only host that enables `features.whisper-server`.
- razer: a client over the tailnet, unaffected by the API.
- `modules/services/whisper-server.nix`.

## Constraints

- Keep the hardening rule: `DynamicUser`, `ProtectSystem = "strict"`,
  `ProtectHome`, `NoNewPrivileges` stay. Only open the GPU render node, not all
  devices.
- Use the nixpkgs build that cache.nixos.org already has (`whisper-cpp-vulkan`,
  1.9.2); no overlay and no local compile.
- The GPU is shared with Ollama (ROCm, 24 GB VRAM). base.en needs well under
  1 GB VRAM, so it must not push Ollama models out.
- Deploying p620 follows the agent-bus announcement rule.

## Open questions

- Should the GPU build be the module default, or a `vulkan` option enabled only
  on p620? (Leaning: an option, so a host without a GPU keeps the CPU build.)
- Now that the GPU makes them cheap, upgrade the model from base.en to a larger
  one (small.en)? Proposed: no, keep base.en and treat that as a separate
  change.
