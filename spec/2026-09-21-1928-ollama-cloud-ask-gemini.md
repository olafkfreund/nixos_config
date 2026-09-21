---
status: approved
issue: 1928
intent: intent/2026-09-21-1928-ollama-cloud-ask-gemini.md
---

# Spec: Retire the dead ask-gemini skill and surface Ollama Cloud models

## Design

Three independent changes. They share an issue because they share a cause —
the consultation surfaces drifted from what is installed — but none depends on
another, so they can land and be reverted separately.

### 1. Hide `ask-gemini` via managed `skillOverrides`

Add to the managed settings in `modules/programs/claude-code-managed.nix`:

```nix
skillOverrides = {
  ask-gemini = "off";
};
```

Managed scope, not user scope, for two reasons. `~/.claude/settings.json` is
Syncthing-synced and must not become a nix-store symlink; and a managed entry
cannot be lost to a plugin update or a settings edit on another host. The
module already composes `permissions` this way (`claude-code-managed.nix:576`),
so `skillOverrides` follows the established shape.

`off` hides the skill from the model *and* from `/`. The alternative values are
`user-invocable-only` (hides from the model only) and `name-only` (collapses
the description); neither is wanted, because the skill cannot run at all and
should not be reachable by either route.

The key is the bare skill name, `ask-gemini`, not the plugin-qualified
`humanize:ask-gemini`. Nested skills listed as `<dir>:name` are covered by the
unqualified name — a fix noted in the CLI changelog for `Skill(name)` deny
rules and managed `skillOverrides` keyed on an alias.

### 2. Name the cloud models in the `ollama-code` MCP description

`home/development/claude-code-mcp.nix:81`. The description string is what
reaches the agent's context, so it is the only place a capability can be
advertised without new code. Extend it to name the `*-cloud` suffix convention
and at least one concrete model, so the existing `model` argument gets used for
something larger than `qwen2.5-coder` when the task warrants it.

No change to the server, the env, or the package.

### 3. Add an `ask-ollama-cloud` skill

A repo-local skill, peer to the existing `ask-codex`, wrapping:

```
ollama run <model> <prompt>
```

with `<model>` defaulting to a cloud model. It reaches the local daemon on
p620, which holds `OLLAMA_API_KEY` in its own environment file and proxies to
`api.ollama.com`. The skill therefore needs no secret of its own — it never
sees the key, which satisfies the #1831 constraint that provider keys stay
unexported.

**Default model: `gpt-oss:120b-cloud`.** It is the one verified to answer from
p620 during this investigation. It is meaningfully larger than the local
`qwen3.8:27b`, which is the only thing that justifies the skill existing at
all; a cloud default smaller than what runs locally would be pointless.

The skill returns text. It does not edit files — consistent with the
delegation principle recorded in #1929: hand off drafting, not committing.

## Alternatives rejected

- **Disable the whole `humanize@PolyArch` plugin.** Considered and chosen
  against once a per-skill mechanism was confirmed. It would also remove
  `ask-codex`, `gen-plan`, `refine-plan`, `start-rlcr-loop` and `explore-idea`,
  all in active use.
- **Delete `skills/ask-gemini/` from the plugin cache.** Undone by the next
  plugin update, and it edits a Syncthing-synced tree.
- **A `permissions.deny` rule on `ask-gemini.sh`.** `Skill(name)` deny rules
  do exist, but deny makes the skill fail loudly when chosen, whereas the
  problem is that it should never be offered. `skillOverrides` removes it from
  the list, which is the actual goal.
- **Shim a `gemini` binary onto `agy`.** The flag surfaces do not correspond
  (`-m`, `-o text`, `--sandbox`, `-p` against agy's `--model`, `--output-format`,
  `--mode`, `--print`), and the shim would re-break on every plugin bump.
- **Reinstate `gemini-cli`.** Reverses #560 and needs `GEMINI_API_KEY`
  exported, which #1831 deliberately prevents.
- **Wire `cloudApiKeyFile` on razer and p510.** Excluded by the approved
  intent. razer runs no Ollama daemon; p510's is `enable = false`. The option
  is a daemon option and would be inert on both.
- **Rely on the MCP tool alone, with no new skill.** Rejected at intent stage:
  an MCP argument is not discoverable the way a slash command is.

## Risks

- **p620** — the only host materially affected. All three changes are
  declarative config or a new file; none restarts the Ollama daemon, touches
  agenix, or changes the service unit. Worst case is an inert setting.
- **A wrong `skillOverrides` value fails silently.** `hidden` and `collapsed`
  look plausible and are not valid. Verification below checks the skill is
  actually gone from the list rather than trusting the build.
- **razer** — sees the MCP description change and the new skill. The skill
  calls `ollama` against `p620:11434`; if razer has no `ollama` client binary
  on PATH the skill fails there. Checked in verification.
- **p510** — unaffected. Not built, not deployed, not asked to.
- **Plugin drift** — if `humanize@PolyArch` renames or removes `ask-gemini`,
  the override becomes a no-op. Harmless, but it means the override should not
  be read later as evidence the skill still exists.

## Verification

1. `just check-syntax` then `just test-host p620` — builds with the new
   managed setting and MCP description.
2. `nix eval` the managed settings attribute and confirm `skillOverrides`
   contains `ask-gemini = "off"` — guards against the setting being dropped by
   the merge at `claude-code-managed.nix:576`.
3. After a switch on p620: start a session and confirm `ask-gemini` is absent
   from the skill list, **and** that `ask-codex` is still present. Both halves
   matter; the first alone would also pass if the whole plugin had been
   disabled by mistake.
4. Confirm `ollama run gpt-oss:120b-cloud` still answers from p620, and that
   the new skill returns its output.
5. On razer, confirm `command -v ollama` succeeds before relying on the skill
   there; if it does not, the skill is p620-only and the description says so.
6. p510 is not built or deployed as part of this change.
