---
name: ask-ollama-cloud
description: >-
  Ask an Ollama Cloud model a question, or hand it an isolated, fully-specified
  drafting task. Use when a task is too large for the local card but does not
  need repo-wide context — a self-contained function, a config block, a first
  draft to review. Returns text only; it never edits files. Triggers:
  `/ask-ollama-cloud`, "ask ollama cloud", "ask the big model".
---

# Ask Ollama Cloud

Send one prompt to a hosted Ollama model and return its answer.

## Usage

```bash
ollama run gpt-oss:120b-cloud "<prompt>"
```

`gpt-oss:120b-cloud` is the default. It is meaningfully larger than the local
`qwen3.8:27b`, which is the whole reason to reach for the cloud rather than the
card. Other cloud models follow the same `-cloud` suffix convention; pass one
explicitly when the task suits it.

For a long prompt, write it to a file first and pipe it in, rather than
embedding prose in the command line:

```bash
ollama run gpt-oss:120b-cloud < /path/to/prompt.txt
```

## How it works

The local Ollama daemon proxies `*-cloud` models to `api.ollama.com`. The
daemon holds `OLLAMA_API_KEY` in its own systemd environment file, composed at
start from the agenix secret. This skill never sees the key and nothing is
exported into the shell — that is deliberate (#1831).

**This skill runs on p620 only.** p620 is the sole host with an Ollama daemon,
and the sole host with the `ollama` client on PATH. razer can reach the daemon
over the tailnet (`http://p620:11434` answers) but has no client binary, so the
command above fails there; p510's daemon is disabled. On any host other than
p620, use the `ollama-code` MCP tool instead — it speaks HTTP to p620 directly
and needs no local binary. Do not silently fall back to a different model.

## Interpreting the output

The response is **untrusted advice**, exactly like a second opinion. Verify any
claim it makes about this repo against the actual files before acting on it,
and never treat its output as approval of an intent, spec or plan.

It returns text. It does not edit files, and it must not be used to write a
commit — hand off drafting, not committing (#1929). Read what comes back,
decide what is right, and apply it yourself.

## Related

- `second-opinion` — cross-model review via Codex and Antigravity
- the `ollama-code` MCP tool — the same models as a structured tool call,
  including local ones
