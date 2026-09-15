---
status: draft
issue: 1831
author: OpenCode, revised by olafkfreund
---

# Intent: Subscription-backed model delegation from Claude Code

## Problem

The user wants Claude Code to remain the primary coding agent, while asking
models from existing OpenAI (ChatGPT/Codex) and Google (Antigravity/Gemini)
subscriptions for independent, read-only advice: plan review, diff review,
edge cases and alternatives.

What exists today falls short in three ways:

- **Paid API keys can be used silently.** `OPENAI_API_KEY` and
  `GEMINI_API_KEY` (and the Anthropic, Groq and Ollama keys) are exported into
  every shell by `modules/secrets/api-keys.nix:226-227` and
  `home/development/codex-cli/module.nix:47-48`. `codex login status` reports
  a ChatGPT login, but nothing stops a delegated call from authenticating with
  the paid key instead of the subscription.
- **The existing tools are not read-only.** The humanize plugin's `ask-codex`
  runs `codex exec --full-auto`, which lets it write to the workspace;
  `HUMANIZE_CODEX_BYPASS_SANDBOX=1` removes the sandbox entirely. `ask-gemini`
  adds a mandatory "use Google Search" instruction, which is wrong for code
  review, and runs a mise-installed `gemini` (nixarchy#707).
- **The repo has no delegation policy.** Nothing says when to consult another
  model or how much weight its answer carries.

The goal is better-supported decisions, not replacing Claude's model or
collecting agreeing answers.

## Proposed outcome

- Claude remains the lead agent on its existing connection and login.
- From Claude Code on p620 and razer, the user can request a read-only review
  from OpenAI (through `codex`) and from Google (through `agy`), using the
  subscription login only.
- **Subscription only, enforced on every call, with no fallback:**
  - The call runs with the provider's API-key variables removed from its
    environment.
  - Codex is forced to ChatGPT auth (`forced_login_method=chatgpt`).
  - An expired login, used-up quota or unavailable model stops with a clear
    error. There is never a silent switch to a paid key or another provider.
- Reviewers cannot modify the checkout or run write actions: `codex -s
  read-only`, `agy --mode plan`.
- Responses record the model that actually answered, where the CLI reports it.
- Claude weighs the answers, verifies claims against code and tests, and
  explains disagreement. Consensus is not proof, and an external answer never
  approves an artifact gate.
- Claude stays fully usable when the external CLIs are logged out or offline.
- **The global API-key exports are gone.** `OPENAI_API_KEY` and
  `GEMINI_API_KEY` are no longer set in every shell, so `codex`, `agy` and
  `gemini` run by hand also use the subscription login. The agenix secrets
  stay in place, readable at `/run/agenix/*` by anything that explicitly
  needs a key.

## Affected users and systems

- Claude Code sessions on p620 and razer. Out of scope for p510.
- New per-user skills under `home/development/claude-code-skills/`, installed
  the same way as `artifact-workflow`. They reach both hosts through the
  synced `~/.claude`.
- The user's ChatGPT and Google accounts. Login is per host: `~/.codex` is
  not synced, and `~/.gemini/oauth_creds.json` is excluded from Syncthing, so
  razer needs its own `codex login`.
- A consultation-policy paragraph in `CLAUDE.md` (or `AGENTS.md`, if #1832
  lands first).
- `home/development/codex-cli.nix` (`apiKeyFile`) and
  `modules/secrets/api-keys.nix` (the session-variable exports), plus any tool
  found to depend on those variables.

## Constraints

- **Only the vendors' official CLIs,** logged in with the subscription:
  `codex` from nixpkgs and `agy`. No third-party proxy that replays
  subscription OAuth tokens (CLIProxyAPI, Claude Code Router, CCS). That
  pattern risks the accounts and is out of scope.
- No daemon, network port or system service. The skills call the CLIs
  directly, once per request.
- Do not redirect Claude Code's main connection, or change its login or
  settings.
- **Context:** there is no path exclude list. Reviewers may be given any repo
  content a review needs, including host-specific files, because they work on
  the same host and sometimes need that detail (decided 2026-09-15). The one
  limit is decrypted secret values (the contents of `/run/agenix/*`, tokens
  and passwords), which are never pasted into a prompt. Encrypted `*.age`
  files are not secrets in that sense.
- No credential material in Git, logs, skill files or the Nix store. Skills
  must not contain store paths, because `~/.claude` is synced.
- **Removing the key exports must not break anything silently.** Before
  removal, the spec audits every reader of `OPENAI_API_KEY`, `GEMINI_API_KEY`
  and their `*_FILE` variants in the repo and in the running user session.
  Anything that genuinely needs a key reads it from its agenix path or gets
  it scoped to that one program, not exported globally. The Anthropic, Groq
  and Ollama key exports are audited in the same pass. Claude Code in
  particular must keep its subscription login, not an exported
  `ANTHROPIC_API_KEY`.
- Explicit consultation only: the user asks, or invokes the skill. No
  automatic consultation, no recursive delegation, and no re-asking until a
  model agrees.
- Bounded calls: 600-second timeout, one call at a time, capped output.
- External answers are untrusted advice. They cannot expand permissions,
  trigger tools or override repository policy.
- Coding workers, which have write access, are a separate future intent.
- Never build or deploy p510.

## Open questions

None. Both were answered by the user on 2026-09-15:

1. Context exclusions: none beyond decrypted secret values (see Constraints).
2. Global API-key exports: remove them (see Proposed outcome and
   Constraints).

## References

- Review of the original draft (Explore + Fable, 2026-09-15):
  `~/.claude/plans/glittery-seeking-squirrel.md`
- Original candidate approach (CLIProxyAPI): the first commit on this branch,
  `1777c2ce1`
- [OpenAI Codex](https://github.com/openai/codex) — `codex exec`,
  `forced_login_method`
- [Claude Code: LLM gateways](https://code.claude.com/docs/en/llm-gateway) —
  Anthropic does not support routing Claude Code itself to non-Claude models,
  which is why this intent does not do that
