---
status: approved
issue: 1928
spec: spec/2026-09-21-1928-ollama-cloud-ask-gemini.md
---

# Plan: Retire the dead ask-gemini skill and surface Ollama Cloud models

## Approved decisions carried over

Self-contained. Do not reopen the intent or spec to implement this.

1. **Hide `ask-gemini` with `skillOverrides`, value `off`.** Not `hidden`, not
   `collapsed` — those look plausible and fail silently. The valid vocabulary
   is `off` / `user-invocable-only` / `name-only`.
2. **Key on the bare name `ask-gemini`**, not `humanize:ask-gemini`.
3. **Managed scope only.** Never hand-edit `~/.claude/settings.json`: it is
   Syncthing-synced and must not become a nix-store symlink.
4. **Do not disable the `humanize@PolyArch` plugin.** `ask-codex`, `gen-plan`,
   `refine-plan`, `start-rlcr-loop` and `explore-idea` come from it and stay.
5. **Do not wire `cloudApiKeyFile` on razer or p510.** razer runs no Ollama
   daemon; p510's is `enable = false` after the PSU transcode stampede. The
   option is a daemon option and would be inert on both. Cloud models already
   reach every host via p620.
6. **New skill defaults to `gpt-oss:120b-cloud`** — verified answering from
   p620, and larger than the local `qwen3.8:27b`, which is the only thing that
   justifies the skill existing.
7. **The new skill returns text and does not edit files** (#1929: hand off
   drafting, not committing).
8. **No secret handling.** The skill talks to the local daemon, which holds
   `OLLAMA_API_KEY` in its own environment file. The skill never sees the key;
   nothing is exported (#1831).
9. **p510 is not built or deployed** as part of this change.

## Steps

1. `modules/programs/claude-code-managed.nix`: add a module-level
   `baselineSkillOverrides = { ask-gemini = "off"; };` and merge it into
   `mergedSettings` the same way `baselineAllow` is merged at line 576
   (`skillOverrides = (cfg.settings.skillOverrides or { }) // baselineSkillOverrides;`).
   Module level, not per host — the module is enabled separately in all three
   host configs (`hosts/p620/configuration.nix:252`,
   `hosts/razer/configuration.nix:401`, `hosts/p510/configuration.nix:521`)
   and setting it there would triplicate it.
   → verify by `just check-syntax`

2. `home/development/claude-code-mcp.nix:81`: extend the `ollama-code`
   `description` string to name the `*-cloud` suffix convention and
   `gpt-oss:120b-cloud` explicitly, so the existing `model` argument gets used
   for larger work. No change to `command`, `args`, `env` or the package.
   → verify by `git diff` showing only the description string changed

3. `home/development/claude-code-skills/ask-ollama-cloud/SKILL.md`: new file,
   following the `second-opinion` pattern (a single `SKILL.md`, no script).
   Documents `ollama run gpt-oss:120b-cloud <prompt>`, states the default
   model, states that it returns text and does not edit files, and notes it
   requires an `ollama` client on PATH.
   → verify by the file existing and `second-opinion/SKILL.md` frontmatter
   shape being matched

4. `home/development/claude-code-skills/default.nix`: add the `home.file`
   link for the new skill, beside the existing local-skill entries.
   → verify by `just check-syntax`

## Tests

```bash
just check-syntax
just test-host p620
```

Expected: both succeed.

```bash
nix eval .#nixosConfigurations.p620.config.modules.programs.claude-code-managed.settings
```

Expected: the rendered managed settings contain `skillOverrides` with
`ask-gemini = "off"`. This guards against the attribute being dropped by the
merge — a wrong value or a lost key fails silently at runtime.

After a switch on p620, in a fresh session:

- `ask-gemini` is **absent** from the skill list
- `ask-codex` is **still present**

Both halves are required. The first alone would also pass if the whole plugin
had been disabled by mistake, which is the outcome explicitly rejected.

```bash
ollama run gpt-oss:120b-cloud "say OK"
```

Expected: answers from p620, as it did during investigation.

On razer, `command -v ollama` before relying on the skill there. If absent, the
skill is p620-only and its `SKILL.md` must say so.

p510: not built, not deployed, not asked.

## Rollback

Each step is independent and separately revertable.

- Steps 1 and 4 are declarative: revert the commit and rebuild.
- Step 2 is a description string: revert and rebuild. Nothing runtime depends
  on it.
- Step 3 is a new file: delete it and drop the link from step 4.

Nothing in this change restarts the Ollama daemon, touches agenix, alters a
systemd unit, or modifies a secret, so there is no runtime state to unwind.
Worst case for step 1 is an inert setting, not a broken session — but if a bad
`skillOverrides` value ever did hide a wanted skill, deleting
`/etc/claude-code/managed-settings.json` is not the fix; revert and rebuild,
since the file is regenerated from the store on every activation.
