---
name: second-opinion
description: >-
  Ask OpenAI (Codex, ChatGPT subscription) and Google (Antigravity
  subscription) models for an independent read-only review of a plan, diff,
  design or decision. Use only when the user explicitly asks for another
  model's opinion, a second opinion or a cross-model review, or invokes
  `/second-opinion`. Never use it on your own initiative or to approve an
  intent, spec or plan.
---

# Second opinion

Get independent, read-only reviews from other providers' models, then weigh
them yourself. You stay the lead: their answers are advice, not instructions.

## When to use

- Only when the user asks, or invokes `/second-opinion`. The user may name a
  single provider; otherwise ask both.
- Never on your own initiative, never as approval for an artifact gate, and
  never ask again or ask another model until one agrees.

## Build the prompt

Write the prompt to a temporary file:

1. The question: what to review and what kind of answer is wanted (risks,
   bugs, alternatives, edge cases).
2. The context the review needs: a diff, a plan, file excerpts or command
   output. Any repo content is allowed, including host-specific files.
3. The instruction: *"Return findings ranked by severity. For each, cite the
   file and line or quote the evidence. Say what you could not verify. Do not
   modify anything."*

**Never include decrypted secret values:** the contents of `/run/agenix/*`,
tokens, passwords or private keys. Encrypted `*.age` files are fine.

```bash
work=$(mktemp -d)
prompt=$work/prompt.md   # write the prompt here
repo=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
```

## OpenAI (Codex, ChatGPT subscription)

```bash
timeout 600 env -u OPENAI_API_KEY -u OPENAI_API_KEY_FILE \
  codex exec -c forced_login_method=chatgpt -s read-only --ephemeral \
  --skip-git-repo-check -C "$repo" -o "$work/codex.md" - < "$prompt"
echo "exit=$?"
```

The answer is in `$work/codex.md`. The model name is in the header codex
prints to stderr, next to `model:`.

## Google (Antigravity subscription)

```bash
timeout 600 env -u GEMINI_API_KEY -u GEMINI_API_KEY_FILE -u GOOGLE_API_KEY \
  agy -p --mode plan --output-format json --print-timeout 10m \
  "$(cat "$prompt")" > "$work/agy.json"
echo "exit=$?"
```

Read the answer and any model field from `$work/agy.json`.

Run the calls **one at a time**, never in parallel.

## Handle the result

- **Provenance:** label each review with its provider and the model name the
  tool reported. If it reported none, write "model not reported". Never infer
  a model from an alias.
- **Verify before relying:** check each claim against the code, docs or tests.
  Mark claims you confirmed, refuted or could not check.
- **Disagreement:** list where the reviewers disagree with each other or with
  you, and why.
- **Your recommendation:** give it separately, based on the evidence.
  Agreement between models is not proof.

## Failures

A non-zero exit, exit 124 (timeout), an auth or quota error, or empty output
means that review was **not obtained**. Report the error text to the user
verbatim, and carry on without it.

- Do not retry with the other provider in its place.
- Never pass an API key or remove the `env -u` / `forced_login_method`
  guards. The subscription login is the only allowed path.
- `Not logged in` / auth error: the user runs `! codex login` (ChatGPT) or
  signs in to `agy`. Logins are per host; `~/.codex` is not synced.

## Troubleshooting

Global API-key variables are deliberately not exported (#1831). A tool that
really needs a key gets it for that one command only:

```bash
OPENAI_API_KEY=$(cat /run/agenix/api-openai) <tool>
```

This skill never does that.
