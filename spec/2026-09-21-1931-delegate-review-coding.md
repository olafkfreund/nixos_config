---
status: approved
issue: 1931
intent: intent/2026-09-21-1931-delegate-review-coding.md
---

# Spec: Use Codex, Ollama and agy for real review and coding

## Design

Five changes. Three extend `second-opinion`; two fix the inert half of #1928.
The existing skill is kept — it already has provenance labelling,
verify-before-relying, disagreement handling and the subscription-only guards.
Nothing about that is replaced; the new paths slot in beside the existing
prose path.

### 1. Routing rule, added to `second-opinion`

Because the skill becomes a dispatcher, it needs one rule stated up front,
before the backend sections:

| Request | Path |
| ------- | ---- |
| Review of a diff, branch or commit in this repo | Codex `review` |
| Review against one of our own agent definitions | agy `--agent` |
| A question, design or plan with no diff to point at | existing prose path (`codex exec` / `agy --mode plan`) |
| "What do both think" / a decision worth disagreement | consensus path |

Explicit non-goal, stated in the skill: this skill routes **review and
drafting only**. It does not become a general dispatcher for arbitrary work,
and no path in it edits files or writes a commit.

### 2. Codex `review` path

```bash
timeout 900 env -u OPENAI_API_KEY -u OPENAI_API_KEY_FILE \
  codex review -c forced_login_method=chatgpt -c sandbox_mode="read-only" \
  --base "$base"
```

`codex review` reads the diff itself, so no prompt file is assembled and the
~100 KB argument limit does not apply. Three selectors: `--base <BRANCH>`,
`--uncommitted`, `--commit <SHA>`.

**Two gotchas found while trialling, both of which must be in the skill:**

- `--base <BRANCH>` **cannot be combined with a custom `[PROMPT]`** — it exits
  with `error: the argument '--base <BRANCH>' cannot be used with '[PROMPT]'`,
  despite the usage line implying both are accepted. Custom review
  instructions and `--base` are mutually exclusive.
- `codex review` has a **much smaller flag surface than `codex exec`**. It
  does **not** accept `-s`, `--ephemeral`, `--skip-git-repo-check`, `-C` or
  `-o`. The read-only guard that `-s read-only` provides on the existing path
  therefore has to come from `-c sandbox_mode="read-only"` instead. This must
  be verified by test, not assumed — see Verification. If it cannot be
  enforced, this path is not adopted.

Output goes to stdout; there is no `-o`, so redirect.

### 3. agy `--agent` path

```bash
timeout 900 env -u GEMINI_API_KEY -u GEMINI_API_KEY_FILE -u GOOGLE_API_KEY \
  agy --agent "$agent" --mode plan --output-format json \
  --print-timeout 10m -p "$(cat "$prompt")" > "$work/agy.json"
```

`agy agents` enumerates this repo's own agent definitions, so our specialist
review criteria run cross-model. `--mode plan` is retained: agy has
`accept-edits` available and it stays unused, deliberately.

All existing agy constraints carry over unchanged — `-p` last, the ~100 KB
single-argument cap, `status`/`response` in the JSON, no model name reported.

### 4. Consensus path

A local shell path in the skill, not a dependency: ask both CLIs the same
question one at a time, then report agreement, disagreement, and what each
could not verify. `planner` from zen/PAL is deliberately not implemented —
planning runs through the intent/spec/plan gates and a competing planner is
not wanted.

The value is the **disagreement**, not the agreement. The skill already says
"Agreement between models is not proof"; the consensus path makes that
concrete by requiring the divergence to be reported explicitly.

### 5. Fix the inert #1928 half

- `pkgs/ollama-mcp/server.py:36` — extend the `ollama_code` docstring to name
  the `-cloud` suffix convention and `gpt-oss:120b-cloud`. This is the text
  the model actually receives, confirmed by loading the live tool schema.
- `home/development/claude-code-mcp.nix:81` — revert the description to its
  previous wording. That file seeds `~/.claude/settings.local.json` only when
  missing (#398, `claude-code-mcp.nix:258-263`), so the string reaches neither
  an existing install nor the model.

## Alternatives rejected

- **zen/PAL MCP** — rejected by the approver. Covers all three backends and
  ships `consensus`/`planner`, but it is a third-party MCP server in a repo
  that keeps its dependency surface small.
- **Separate sibling skills per backend** — rejected by the approver;
  `second-opinion` stays the single entry point.
- **Replacing the existing `codex exec` prose path with `review`** — rejected.
  `review` only works when there is a diff. A design question or a plan with
  nothing committed still needs `exec`. Both paths stay.
- **Using `agy --mode accept-edits`** — rejected. It exists and stays unused;
  these models advise, they do not edit.
- **Fixing the MCP description in `claude-code-mcp.nix`** — rejected as
  already proven not to work.
- **Letting a delegated review approve an artifact gate** — rejected by
  CLAUDE.md and reinforced by the agy trial, which reasoned correctly while
  citing files under a directory that does not exist.

## Risks

- **`codex review` may not be pinnable to read-only.** The flag surface does
  not include `-s`. If `-c sandbox_mode="read-only"` does not take effect,
  adopting this path would silently drop a guard the current skill enforces.
  This is the one risk that can sink change 2, and it is tested first.
- **`second-opinion` grows into a router.** Mitigated by the explicit
  non-goal above; the file should stay readable in one sitting.
- **Docstring edits change the MCP tool contract.** `server.py` is a package;
  the description reaches the model only after a rebuild, and the running MCP
  server must be restarted to pick it up.
- **p620 and razer** only. p510 unaffected: not built, not deployed.
- **No secret ever reaches a model.** The existing prohibition on decrypted
  `/run/agenix/*` values carries over. `codex review` reads the diff itself,
  which narrows rather than widens exposure.

## Verification

1. **Read-only enforcement, first and blocking.** Run the Codex `review` path
   with `-c sandbox_mode="read-only"` against a branch with uncommitted
   changes present, then confirm `git status --porcelain` is byte-identical
   before and after, and that no file mtime changed. If the guard cannot be
   demonstrated, change 2 is dropped and the spec is revised.
2. `codex review --base <rev>` returns findings with file:line on a real
   diff — already demonstrated once: it found the inert MCP description in
   PR #1930.
3. `agy --agent nix-check` runs and returns a usable answer — already
   demonstrated. Re-check that `--agent` with an unknown name fails loudly
   rather than silently falling back to the default agent.
4. The consensus path returns both answers and an explicit disagreement
   section, on a question where the two models are likely to differ.
5. After a rebuild and an MCP restart, the live `ollama_code` tool schema
   contains the cloud-model text. Verified by loading the tool, not by reading
   `server.py` — that distinction is the whole reason this issue exists.
6. `just check-syntax`, `just test-host p620`.
7. The reverted `claude-code-mcp.nix` description matches its pre-#1930
   wording exactly (`git show` against the merge base).
