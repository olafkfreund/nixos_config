---
status: draft
issue: 1928
author: olafkfreund
---

# Intent: Retire the dead ask-gemini skill and surface Ollama Cloud models

## Problem

The AI-consultation surfaces available to the agent no longer match what is
installed on these hosts. Two symptoms, one cause.

**`/humanize:ask-gemini` cannot run.** Its script exits 1 at a
`command -v gemini` prerequisite check. There is no `gemini` binary on any
host and there is not meant to be: gemini-cli was removed in #560 in favour
of `customPkgs.antigravity-cli` (`pkgs/default.nix:24`), and the nixarchy app
entry is commented out (`hosts/p620/nixarchy/apps.nix:108`). The skill comes
from the third-party `humanize@PolyArch` plugin, which assumes the upstream
Google CLI is present. The skill is also redundant here: CLAUDE.md already
designates `second-opinion` (via `agy`) as the only sanctioned route to a
Google model, and that route works. So the skill is pure noise in the skill
list, and it fails only after the user has already chosen it.

**Ollama Cloud works but nothing says so.** The API key is decrypted to
`/run/agenix/api-ollama` and composed into the daemon environment on p620
(`hosts/p620/configuration.nix:180`, `modules/services/ollama.nix:215-220`).
Cloud models answer today. But `ollama_list_models` reports only locally
pulled models, and the `ollama-code` MCP description mentions only
`qwen2.5-coder`. Nothing in the agent's context indicates that passing a
`*-cloud` model name reaches a far larger hosted model, so the capability is
paid for and never used.

## Proposed outcome

- `ask-gemini` no longer appears in the skill list on any host. The other
  skills from the same plugin — `ask-codex`, `gen-plan`, `refine-plan`,
  `start-rlcr-loop`, `explore-idea` — continue to work untouched.
- The Ollama Cloud models are discoverable from the agent's context without
  the user having to remember the `-cloud` suffix convention.
- There is a first-class way to ask a cloud model a question, as a peer to
  the existing `ask-codex`, rather than only an MCP tool argument.

## Affected users and systems

- **p620** — the only host running an Ollama daemon, and the only one holding
  the cloud key. The MCP client on razer already points here.
- **razer** — consumes the `ollama-code` MCP over the tailnet; sees the
  description change and the new skill.
- **p510** — no change. Its Ollama daemon is `enable = false` and stays that
  way.
- `modules/programs/claude-code-managed.nix` — managed Claude settings.
- `home/development/claude-code-mcp.nix` — MCP server declarations.
- No service restart, no deploy to p510, no secret rekey.

## Constraints

- **Must not** wire `services.ollama.cloudApiKeyFile` on razer or p510. An
  earlier reading of this problem proposed exactly that; it is wrong. razer
  runs no Ollama daemon at all, and p510's is deliberately disabled after the
  PSU transcode stampede. `cloudApiKeyFile` is a daemon option, so on both
  hosts it would be inert. Cloud models already reach every host via p620.
- **Must not** disable the `humanize@PolyArch` plugin wholesale. A per-skill
  mechanism exists and the plugin's other skills are in active use.
- **Must not** hand-edit `~/.claude/settings.json`. That directory is
  Syncthing-synced and must not become a nix-store symlink; enforced settings
  belong in managed scope.
- **Must not** export an API key into the environment to make any of this
  work. #1831 deliberately un-exported the provider keys; the Ollama key
  stays confined to the daemon's own environment file.
- The `skillOverrides` value vocabulary is `off` / `user-invocable-only` /
  `name-only`. A plausible-looking `hidden` or `collapsed` is not valid and
  would fail silently.

## Open questions

None. Three decisions were taken before this was written:

1. Kill only `ask-gemini` via `skillOverrides`, not the whole plugin.
2. Exclude the razer/p510 key wiring as unnecessary.
3. Add a dedicated cloud-consultation skill in addition to annotating the
   MCP description, rather than relying on the MCP tool alone.

The choice of which cloud model the new skill defaults to is a spec-stage
question, not an intent-stage one.
