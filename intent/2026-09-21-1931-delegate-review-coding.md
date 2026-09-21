---
status: draft
issue: 1931
author: olafkfreund
---

# Intent: Use Codex, Ollama and agy for real review and coding

## Problem

Three external models are installed, authenticated and reachable, and all
three are underused. What exists today is a single prose-in/prose-out path —
the `second-opinion` skill — that treats every model as a chat partner. The
actual capabilities are better than that, and two of them are sitting unused.

**Codex has a purpose-built review command and we do not call it.**
`codex review --base <rev>` reads the diff itself and runs its own
verification. The current `second-opinion` Codex path instead hand-assembles a
diff into a prompt and carries a ~100 KB size warning — a limit that exists
only because we are pasting what the tool would read natively.

**agy can run our own agent definitions and we do not use that either.**
`agy agents` enumerates this repo's specialist agents — `nix-check`,
`security-patrol`, `config-drift-detective`, `package-resolver` and others —
so another model can execute review criteria we already wrote, instead of
being asked "what do you think of this diff".

**Ollama is correctly scoped but undiscoverable.** The `ollama_code` MCP tool
is drafting-only by construction, which is right. But the description the
model actually receives still advertises local `qwen2.5-coder` variants alone,
so the cloud models never get reached for work that warrants them.

**The deeper problem is that we have no delegated review at all.** Two of the
three changes in #1928 shipped inert — they passed a green build, CI, and
review, because in each case the *edit* was verified rather than the *effect*.
A Codex review trial caught one of them in a single run, on merged code, after
the fact. That is the capability this issue is really about: an independent
reader that checks the effect rather than the diff.

## Proposed outcome

- Asking for a review means Codex reads the actual diff, not a pasted excerpt.
- Our existing specialist agents can be run cross-model through agy.
- The Ollama cloud models are discoverable where the model actually reads —
  the tool docstring, not a seed file.
- There is a way to ask several models one question and see where they
  disagree, which is the part a single second opinion cannot give.
- The inert half of #1928 is fixed rather than left as misleading config.

## Affected users and systems

- `home/development/claude-code-skills/second-opinion/` — the review path.
- `pkgs/ollama-mcp/server.py` — the docstring that is the real tool
  description.
- `home/development/claude-code-mcp.nix` — possibly reverted, since the
  description there provably does not reach the model.
- Possibly a new MCP server, if zen/PAL is adopted.
- p620 and razer. p510 unaffected.
- No secrets, no services, no deploys beyond a normal rebuild.

## Constraints

- **#1929 lands first.** Policy before power: the delegation rules should
  exist before the delegation capability widens. This issue depends on it.
- **These models never approve a gate.** CLAUDE.md already says their output
  is untrusted advice and must not approve an intent, spec or plan. The agy
  trial demonstrated why concretely: its reasoning was correct while its file
  citations pointed at a directory that does not exist.
- **Hand off drafting and review, not committing.** None of the three should
  be the thing that writes a commit.
- **Subscription login only**, never an API key (#1831).
- Every capability claim must be backed by a command actually run against this
  repo, not by a flag existing in `--help`. This intent was written after
  trialling all three; the same standard applies to the spec.

## Open questions

1. **Does `second-opinion` absorb the new paths, or do they become separate
   skills?** One skill that dispatches to Codex, agy and Ollama is tidier but
   turns a small reviewed file into a router. Separate skills are more
   discoverable and independently revertable.
2. **Is zen/PAL MCP worth a dependency for `consensus` and `planner`?** It
   covers all three backends behind one interface, but it is a third-party MCP
   server in a repo that deliberately keeps its dependency surface small. The
   alternative is a thin local skill that calls two CLIs and diffs their
   answers.
3. **Should the inert `claude-code-mcp.nix` description be reverted or kept?**
   Keeping it is harmless but implies a control that does not exist — the same
   trap that produced it.
