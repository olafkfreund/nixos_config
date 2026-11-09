---
status: draft
issue: 2812
intent: intent/2026-11-09-2812-skip-permissions.md
---

# Spec: run agy and Codex unrestricted, everywhere

## Design

Every launch path that Claude uses starts the tool directly, unrestricted. The sandbox wrappers (`agent-review`,
`agent-implement`, `agent-sandbox.sh`) and their tests stay in the repo, unused by default, so going back is a
revert.

| Launch path | Today | After |
| ----------- | ----- | ----- |
| Codex review, `second-opinion` (`SKILL.md:92`, `:145`) | `herdr-run codex timeout … agent-review codex "$work" -- review\|exec -s read-only …` | `herdr-run codex timeout … codex review\|exec --dangerously-bypass-approvals-and-sandbox -c forced_login_method=chatgpt …` |
| agy review, `second-opinion` (`:157`, `:188`) | `herdr-run agy timeout … agent-env agy --mode plan …` | `herdr-run agy timeout … agy --dangerously-skip-permissions --mode plan …` |
| Codex implement, `codex-implement` (`codex-cli.nix:27-37`) | guard preflight, then `agent-implement codex -- -p implement …` | guard preflight, then `exec codex -p implement --dangerously-bypass-approvals-and-sandbox -c forced_login_method=chatgpt "$@"` |
| agy implement, `agy-implement` (`antigravity-config.nix`) | guard and probe preflight, then `agent-implement agy -- --mode accept-edits --sandbox --dangerously-skip-permissions …` | guard and probe preflight, then `exec agy --mode accept-edits --dangerously-skip-permissions $model "$@"` with `AGY_CODER=1` and `AGY_WORKTREE=<repo root>`, as before #2757 |
| `handoff` / `agent-run` (`agent-run.sh:46,51`) | calls `codex-implement` / `agy-implement` via `herdr-run` | unchanged; it inherits the new launchers |
| #2810 `herdr-team` members | the sandboxed `--tui` modes | #2810's Amendment 2 (separate PR) |

Kept on purpose:

- **`herdr-run`.** The visible pane and the env allow-list stay. Dropping the allow-list buys nothing, and keeping
  it stops a token from leaking into a log by accident. It is hygiene, not a boundary: the files are readable
  anyway.
- **The coder guards** (`/etc/codex/hooks/coder-guard`, agy's guard adapter) and their preflight. They still
  refuse `git commit`, `nix … switch` and other deploy commands. That is now the only mechanical check, and a
  determined agent can get around it.
- **`agent-run`'s six checks.** It still refuses `~/.config/nixos` and `main`, and checks `HEAD`, the diff and
  the exit.
- **`forced_login_method=chatgpt`, and `env -u` of every API-key variable,** for subscription login only (#1831).
- **The headless reviews' read-only role.** It is now enforced only by `--mode plan` (agy), and by the prompt
  ("Do not modify anything"). For Codex, `review` is read-only by nature, and `exec` is told so in the prompt.

Docs:

- `AGENTS.md`, "Delegating to other models":
  - the ban (`:84`) is replaced by the new rule and the owner decision of 2026-11-09;
  - the instruction-only rules are listed, as in the intent's table;
  - the `agent-review` and `agent-implement` paragraphs say they are unused by default and kept for going back.
- **`second-opinion` and `handoff` SKILL.md:** the new commands; the "Never" list loses the flag ban and keeps
  "no API key" and "no `HUMANIZE_CODEX_BYPASS_SANDBOX`".
- **`modules/programs/claude-code-managed-claude.md`:** one line saying that delegated agents run unrestricted
  by owner decision, and that the commit/deploy/p510 rules are instructions.

## Alternatives rejected

- **A narrow `permissions.allow` rule for agy's reviews.** It would fix the failures with less exposure, but the
  owner chose unrestricted on every path.
- **Keeping the sandbox and only adding the flag inside it.** That was offered as the recommended option, and the
  owner declined it.
- **Deleting the wrappers.** Keeping them makes going back a revert. They cost nothing while unused.

## Risks

- **Prompt injection from repo content, a web page or another agent can act as the owner.** That includes using
  the herdr socket to answer Claude's own permission prompts. Accepted by the owner.
- **A reviewer that edits files.** agy's `--mode plan` should stop that, and Codex `exec` is told not to. Claude
  checks `git status` after every review and reports any change.
- **Merge order with #2810.** #2810's step 1 also edits `codex-cli.nix` and `antigravity-config.nix`. #2812 lands
  first. #2810 rebases, and its Amendment 2 drops the wrapper path for members.
- **Hosts:** p620, razer and p510, through the shared Home Manager modules. p510 is built and deployed only with
  the owner's OK.

## Verification

- `nix build` of the p620 and razer `home.path`. A p510 eval only.
- `bash home/development/agent-run.test.sh` passes (`agent-run` is unchanged).
- `codex-implement` and `agy-implement` still refuse when their guard is missing (preflight unchanged).
- Live, from this session, after deploy on p620:
  - a `second-opinion` agy review that needs a shell command now completes, where before it failed with the
    `jetski … auto-denied` error. `git status` is clean afterwards;
  - a Codex `exec` review completes;
  - a `handoff` through `agent-run codex` edits a scratch worktree and returns `ok: true`;
  - the guard still blocks `git commit` from the implementer.
- razer: the same agy review, run over SSH.
