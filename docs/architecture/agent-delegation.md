# Agent delegation: legacy sandbox details

`AGENTS.md` holds the live rules for delegating to Codex, agy and Ollama. This
page keeps the history that no longer applies by default, so a revert of
Issue #2812 can find it.

## Codex implementation (legacy, Issue #2812)

`codex-implement` used to run in `agent-implement` with no secrets, no Nix
daemon socket and a read-only `.git`, so it could not stage. Claude staged and
committed (Issue #2757). The guard still enforces the no-commit, no-deploy
rule (Issue #2081).

## agy implementation (legacy, Issue #2812)

`agy-implement` ran in `agent-implement` too, with the same limits
(Issue #2757). Two exposures remained open: its commands had outbound network,
and `--sandbox` was the only thing that blocked abstract sockets such as
`@1PASSWORD_MCP`. The guard enforces the no-commit, no-deploy rule
(Issues #2087, #2291).

## Delegated reviews through `agent-review` (legacy, Issue #2812)

Delegated Codex reviews ran through `agent-review`. It gave them read-only
commands and archive tools, no secrets mounted and no Nix daemon socket,
because `olafkfreund` is a trusted user of the daemon on p510 and can still
start daemon builds on p620 and razer (Issue #2758). So `nix build` and flake
evaluation were unavailable there: Claude ran them and passed in the output.

- Codex could read its own login (`~/.codex/auth.json`) and nothing else of
  `~/.codex`.
- Its commands had no network because Codex's inner read-only sandbox blocked
  it, not the wrapper: the parent process needed the network.
- The work dir had to be under `/tmp` and owned by you, and the repo had to be
  a git worktree.
- With no config the default model was used, and only `model`,
  `model_reasoning_effort` and `review_model` could be set with `-c`.
- Delegated agy, when used, stays in `--mode plan` (with
  `--dangerously-skip-permissions`, Issue #2812), and is off the team by the
  owner's choice.
- Do not use `codex exec` for edits or `agy --mode accept-edits` in reviews
  against this tree.

`agent-review`, `agent-implement` and `agent-sandbox.sh` stay in the repo,
unused by default, so going back is a revert.
