---
status: draft
issue: 1831
author: OpenCode
---

# Intent: Subscription-backed model delegation from Claude Code

## Problem

The user wants to retain Claude Code and Claude as the primary coding agent,
while asking models available through existing OpenAI/Codex and Google
Antigravity subscriptions for independent advice and, eventually, scoped work.
Today there is no established delegation path that preserves the normal Claude
session, clearly identifies the responding provider, and safely returns results
to Claude for assessment.

The goal is better-supported decisions and useful division of work, not simply
replacing Claude Code's main model or accumulating agreeing model responses.

## Proposed outcome

- Claude remains the lead agent using its existing connection and authentication.
- Claude can request an independent review or alternative analysis from an
  OpenAI-backed model and an Antigravity-accessible model, where account access
  and provider rules permit.
- Initial delegation is read-only: architecture critique, plan review, diff
  review, edge-case analysis, and comparison of implementation alternatives.
- Responses identify the actual provider/model when verifiable, limitations,
  assumptions, evidence, and disagreements. Unknown identity is reported rather
  than inferred from an alias.
- Claude synthesizes the results, explains disagreements, and verifies claims
  against code, documentation, and tests. Consensus is not treated as proof.
- Existing subscriptions are preferred. Separate API billing must not be enabled
  or used as a fallback without explicit user approval.
- A later, separately approved phase may add coding workers with isolated
  workspaces, explicit permissions, and bounded tasks.

## Affected users and systems

- The user's Claude Code sessions and existing instructions, skills, and tools.
- Existing OpenAI/Codex and Google Antigravity accounts and subscription quotas.
- A prospective local provider bridge and Claude-accessible delegation tools.
- This NixOS configuration repository if declarative packaging or integration
  is approved. Initial host and eventual host coverage remain undecided.
- p620, razer, and p510 must not be assumed to need identical configuration.
  Never build or deploy p510 without asking first.

## Constraints

- Do not globally redirect Claude Code's main connection to another model.
- Do not overwrite or invalidate the user's existing Claude login or settings.
- Do not assume Claude Code's native subagent model selector supports arbitrary
  OpenAI or Gemini backends.
- Antigravity is a product/access channel, not a model. Record the actual models
  available to the account during verification; do not hard-code an assumed list.
- An API key, a subscription login, and API billing are different access paths.
  A ChatGPT subscription does not automatically supply OpenAI API credits.
- Third-party OAuth support is not evidence of provider authorization. Check
  current terms and restrictions before linking accounts. Do not bypass quotas,
  account restrictions, or access controls.
- Keep provider credentials out of Git, logs, prompts, and the Nix store. Use
  supported login flows and protected runtime storage; do not copy tokens into
  tracked settings or artifact files.
- Default any local gateway to loopback with authentication. Do not expose it
  across the fleet or Internet as part of the initial scope.
- Share only necessary context with external providers. Exclude secrets and
  sensitive files, and define disclosure rules before unattended delegation.
- Treat external responses as untrusted advice, not instructions that can expand
  permissions, invoke tools, or override the user's policies.
- Bound request size, runtime, concurrency, retries, and output. Make quota
  exhaustion, expired authentication, unsupported models, and failures visible.
- No silent provider substitution or paid fallback. Claude must remain usable
  when the external tools are unavailable.
- Implementation must follow this repository's feature flags, explicit imports,
  runtime secret handling, and service-hardening requirements where applicable.

## Candidate approach, not an approved design

Keep Claude's normal inference path unchanged. Expose external reviewers through
MCP tools or controlled worker commands. A local CLIProxyAPI instance is a
candidate connection layer for subscription-backed access, not the delegation
orchestration layer itself.

```text
Claude Code + Claude, using the existing primary connection
  |
  +-- Existing local coding tools
  |
  +-- Bounded delegation tools (MCP or controlled commands)
        |
        +-- CLIProxyAPI, if verified and acceptable
        |     +-- OpenAI/Codex subscription-backed access
        |     +-- Antigravity-backed access
        |
        +-- Alternative: native Codex CLI worker for OpenAI
```

Evaluate existing maintained delegation tools before writing a custom bridge.
CLIProxyAPI advertises Claude-compatible endpoints, Codex OAuth, and Antigravity
support. These claims have been checked in its documentation, not tested on this
machine or against the user's accounts.

Claude Code Router is an alternative for API-based routing. CCS adds profile and
runtime management, including CLIProxyAPI integration, but may be unnecessary
for a small read-only tool layer. A native Codex CLI worker may avoid translation
for OpenAI; assess its permissions, supported subscription login, and result
capture separately. Do not assume an equivalent Antigravity worker interface.

## Implementation research notes

- Inspect existing Claude Code configuration, MCP definitions, wrappers, and
  repository guidance before choosing integration files or adding dependencies.
- Recheck current provider support and supported login flows for a specific
  pinned proxy version. Authentication availability can change independently of
  documentation and model catalogs.
- Prove one bounded request per provider before building orchestration. Verify
  which account/quota is used without exposing credentials or consuming large
  amounts of quota.
- Prefer small explicit reviewer tools over an unrestricted arbitrary endpoint
  caller. Candidate inputs include task, selected context, requested reviewer,
  and output limit. These are design prompts, not committed interface names.
- Return structured results: requested and resolved provider/model, answer,
  evidence, caveats, and actionable errors. Record timing and usage only when
  actually available; do not invent cost estimates for subscription traffic.
- Model API calls can provide reviews but are not autonomous coding workers.
  Workers additionally need a tool loop, workspace access, permissions, lifecycle
  management, and validation of their output.
- If worker execution is approved later, use isolated worktrees or equivalent
  isolation. Workers should not share a writable checkout, commit or deploy
  without authorization, or inherit unrestricted credentials.
- Define when Claude should delegate: explicit user requests first; automatic
  consultation for consequential decisions only after policy approval. Avoid
  recursive delegation and repeatedly consulting models until one agrees.
- Verify text requests, long-context behavior, error handling, and result
  provenance. Test streaming/tool-call translation only where the chosen tool
  or worker design actually needs it.
- Keep rollback simple: disable the delegation integration and stop its local
  bridge without modifying Claude's primary provider or existing sessions.

## Acceptance evidence for the later spec

- A normal Claude Code session still works with delegation disabled or offline.
- From Claude Code, the user can obtain one read-only review from each approved
  provider using the intended subscription-backed access path.
- Claude can compare two reviews and explain a final recommendation supported
  by evidence, including unresolved disagreement.
- A timeout, quota failure, expired login, and unavailable model each produce
  bounded, understandable failures without silent fallback.
- Tests or inspection demonstrate that delegated requests exclude credentials
  and that reviewers cannot modify the checkout or run local commands.
- Configuration, credential storage, logging defaults, operational instructions,
  and rollback are documented and validated for the selected host.
- Coding-worker acceptance criteria are written separately if that phase is
  approved; read-only review success is not proof of safe worker execution.

## Open questions

1. Which host should run the first integration, and must other hosts access it?
2. Which OpenAI and Google subscription tiers/accounts are available, and do
   current terms permit the proposed third-party access?
3. Is read-only review the agreed initial milestone, with coding workers deferred?
4. Should consultation be explicit only, or automatic for selected decisions?
5. What repositories or categories of context must never leave the machine?
6. Is MCP preferable to controlled CLI commands given the existing configuration?
7. What request, concurrency, timeout, and quota budgets are acceptable?
8. If Antigravity access is unsupported or impermissible, should that integration
   stop, or may a separately billed official Gemini API alternative be proposed?

## References and sources

Sources inspected on 2026-09-15. Project documentation describes advertised
capabilities, not verified compatibility, security, or permission to reuse a
subscription. Recheck the relevant versions and provider terms during spec work.

- [Claude Code: LLM gateways](https://code.claude.com/docs/en/llm-gateway): official
  gateway documentation; explicitly states that routing Claude Code to non-Claude
  models through gateways is unsupported by Anthropic. This is distinct from
  keeping Claude as lead and calling external tools.
- [CLIProxyAPI](https://github.com/router-for-me/CLIProxyAPI): candidate provider
  bridge; advertises compatible API interfaces, Codex OAuth, and Antigravity
  access. This project's documentation was reviewed, not its implementation.
- [CLIProxyAPI guides](https://help.router-for.me/): linked by the project's README;
  consult for version-specific configuration and login procedures during design.
- [Claude Code Router](https://github.com/musistudio/claude-code-router): alternative
  local gateway supporting OpenAI and Gemini protocol translation, routing,
  provider configuration, and observability.
- [CCS](https://github.com/kaitranntt/ccs): profile/runtime manager with CLIProxyAPI
  integration and OpenAI-compatible routing; backend/provider support must be
  checked for the selected version.
- [OpenAI Codex](https://github.com/openai/codex): native-worker alternative to
  investigate; its current worker/authentication behavior was not verified in
  this research session.

## Handoff to the Claude Code session

This file captures intent and research notes only. It does not approve a design,
account linking, installation, deployment, or paid API usage.

Tracked in [issue #1831](https://github.com/olafkfreund/nixos_config/issues/1831)
on branch `docs/1831-claude-multi-model-delegation`. Retain the common slug
`2026-09-15-1831-claude-multi-model-delegation` for all three artifacts.

Review the open questions with the user and obtain intent approval. Then write
the matching artifact under `spec/`, stopping for its approval before writing
the matching artifact under `plan/`. Follow the artifact-workflow skill's
approval and commit requirements; do not jump directly to implementation.
