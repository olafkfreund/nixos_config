---
status: approved
issue: 3263
intent: intent/2026-11-27-3263-agent-team-role-map.md
---

# Spec: One role map for Claude, Codex and agy models

## Design

New file `modules/programs/agent-team.nix`: a plain attrset (no options, no
`config`), imported by path wherever it is read.

```nix
{
  roles = {
    manager  = { claude = { model = "opus";   effort = "high";   }; codex = { model = "gpt-6.2-astra"; effort = "high";   }; agy = { model = "gemini-4-neon";     effort = "high";   }; };
    reviewer = { claude = { model = "opus";   effort = "medium"; }; codex = { model = "gpt-6.2-astra"; effort = "medium"; }; agy = { model = "gemini-4-neon";     effort = "medium"; }; };
    worker   = { claude = { model = "sonnet"; effort = "medium"; }; codex = { model = "gpt-6.2-sol";   effort = "medium"; }; agy = { model = "gemini-4-hydrogen"; effort = "medium"; }; };
    explorer = { claude = { model = "haiku";  effort = "low";    }; codex = { model = "gpt-6-luna";    effort = "low";    }; agy = { model = "gemini-4-hydrogen"; effort = "low";    }; };
  };
  limits = { subagents = 4; depth = 1; };
}
```

Consumers:

- `modules/programs/claude-code-managed.nix`: `CLAUDE_CODE_SUBAGENT_MODEL`,
  `CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS`, `CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH`
  from the map (same values as today). The coder agent file gets `@model@` and
  `@effort@` placeholders, filled from `worker.claude`, plus
  `experimental: { cacheTtl: 1h }` (it is re-addressed by SendMessage after
  more than the 5-minute default).
- `home/development/claude-code-agents.nix`: Explore's `model` and `effort`
  from `explorer.claude`, plus `omitClaudeMd: true`.
- `home/development/codex-cli.nix`: `implement.config.toml` from
  `worker.codex` (Sol moves from `gpt-6-sol` to `gpt-6.2-sol`); new
  `manager.config.toml` from `manager.codex` with `review_model` from
  `reviewer.codex`; both profiles carry `[agents] max_threads`/`max_depth`
  from `limits`; a `codex-manager` alias (`codex -p manager`). The
  `codexReviewModel` activation forces the root `review_model` to
  `reviewer.codex` (today it only seeds it when absent).
- `home/development/antigravity-config.nix`: `agy-implement`'s CLI default
  `<model>-<effort>` and ACP `--model <model> --effort <effort>` from
  `worker.agy` (same values as Phase 0).
- `home/development/agent-run.nix` + `herdr-team.sh`: the build prefixes
  `review_model` / `review_effort` (from `reviewer.codex`); both review-member
  argv branches add `-c model="…" -c model_reasoning_effort="…"`.
  `herdr-team-test.sh` updates its expected launch line.

Checked on codex 0.172.0: a profile file with `[agents] max_threads`/`max_depth`
loads; an unknown key under `[agents]` is rejected; `gpt-6.2-sol` runs.
`codex -p <profile> debug prompt-input x` validates a profile without a model
call.

## Alternatives rejected

- A NixOS/HM option set: both sides would need the same option twice or
  `osConfig` plumbing; hosts do not differ, so data is enough.
- `CLAUDE_CODE_SUBAGENT_MODEL_FORCE`: would downgrade per-agent reviewers.
- Global `subagentPromptCacheTtl: 1h`: one-shot subagents would pay 1-hour
  cache writes for nothing.
- Writing `~/.codex/config.toml` from Nix: Codex rewrites it (trust records,
  MCP entries).

## Risks

- `gpt-6.2-sol` behaves differently from `gpt-6-sol` for codex-implement
  (same tier, newer). Revert is one value.
- Forcing `review_model` overwrites a hand-set value in `config.toml`.
- Unknown coder frontmatter is ignored silently, so a mistyped `cacheTtl`
  would do nothing rather than break.

## Verification

- `just test-host p620`, `just test-host razer` (herdr-team's build-time test
  runs inside them).
- `nix eval` of p620's managed settings env and the coder agent text.
- After deploy: `codex -p manager debug prompt-input x` and
  `codex -p implement debug prompt-input x` exit 0; `grep review_model ~/.codex/config.toml`
  shows the reviewer model; `~/.claude/agents/Explore.md` has `omitClaudeMd`.
