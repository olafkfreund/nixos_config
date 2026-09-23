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

## What this skill will not do

This skill routes **review and drafting only**. It is not a general
dispatcher for arbitrary work.

- **No path here edits a file or writes a commit.** Codex `review` is pinned
  read-only, agy stays in `--mode plan`, and Ollama's MCP tool cannot reach
  the filesystem at all. `codex exec` with write access and
  `agy --mode accept-edits` both exist and are deliberately unused.
- **Never set `HUMANIZE_CODEX_BYPASS_SANDBOX`.** The humanize plugin's
  `ask-codex.sh` swaps in `--dangerously-bypass-approvals-and-sandbox` when
  it is `true`/`1`. This repo deploys three hosts and holds agenix secrets.
- **Nothing here approves an artifact gate.** Not an intent, not a spec, not
  a plan. Two models agreeing is not an approval.
- Hand off drafting and review. Keep the deciding and the committing.

## Which path to use

| What you have | Path |
| ------------- | ---- |
| A diff, branch or commit in this repo | **Codex `review`** — it reads the diff itself |
| A review that matches one of our own agent definitions | **agy `--agent`** |
| A question, design or plan with no diff to point at | **prose path** (`codex exec` / `agy --mode plan`) |
| A decision where disagreement is the point | **consensus** — ask both, report the divergence |

The prose path is the fallback, not the default. If there is a diff, prefer
`codex review`: it reads the repo natively, so nothing has to be pasted and
the 100 KB argument cap does not apply.

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

## Codex `review` — when there is a diff

Preferred for anything already in git. Codex reads the diff itself, runs its
own verification commands, and reports findings with severity and file:line.
No prompt file, no pasting, no size cap.

```bash
timeout 900 env -u OPENAI_API_KEY -u OPENAI_API_KEY_FILE \
  codex review -c forced_login_method=chatgpt -c sandbox_mode="read-only" \
  --base "$base" > "$work/codex-review.md"
echo "exit=$?"
```

Three selectors, pick one:

- `--base <BRANCH>` — everything on this branch versus that base
- `--uncommitted` — staged, unstaged and untracked changes
- `--commit <SHA>` — the changes one commit introduced

**Two traps, both hit in testing:**

1. **`--base` cannot be combined with a custom prompt.** It exits with
   `error: the argument '--base <BRANCH>' cannot be used with '[PROMPT]'`,
   even though the usage line lists both. Custom review instructions and
   `--base` are mutually exclusive — use `--uncommitted` with a prompt, or
   `--base` without one.
2. **`review` takes far fewer flags than `exec`.** No `-s`, no `--ephemeral`,
   no `--skip-git-repo-check`, no `-C`, no `-o`. Read-only therefore comes
   from `-c sandbox_mode="read-only"`, not `-s read-only`. That was verified
   by running it against a tree with uncommitted changes and confirming
   `git status --porcelain` came back byte-identical. **Never drop that
   `-c`** — without it this path has no proven write guard.

Output is stdout, so redirect it.

## OpenAI (Codex, ChatGPT subscription) — the prose path

For a question, design or plan with no diff to point at.

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
  agy --mode plan --output-format json --print-timeout 10m \
  -p "$(cat "$prompt")" > "$work/agy.json"
echo "exit=$?"
jq -r '.status, .response' "$work/agy.json"
```

- `-p` takes the prompt as its own value, so it must come last. `-p --mode …`
  makes `--mode` the prompt and exits 2.
- The prompt is a single argument, and Linux caps one argument at 128 KiB.
  Keep the agy prompt under about 100 KB: trim the diff to the relevant
  files, or summarise, rather than sending it all.
- The JSON has `status`, `response` and `usage`, but no model name. Label the
  review "model not reported".

Run the calls **one at a time**, never in parallel.

## agy `--agent` — run one of our own agent definitions

agy can execute this repo's specialist agents, so review criteria we already
wrote run against a second model. `agy agents` lists the available names
(`nix-check`, `security-patrol`, `config-drift-detective`,
`package-resolver`, `module-refactor`, `test-generator` and others).

```bash
timeout 900 env -u GEMINI_API_KEY -u GEMINI_API_KEY_FILE -u GOOGLE_API_KEY \
  agy --agent "$agent" --mode plan --output-format json \
  --print-timeout 10m -p "$(cat "$prompt")" > "$work/agy.json"
echo "exit=$?"
jq -r '.status, .response' "$work/agy.json"
```

Same constraints as the plain agy path: `-p` last, ~100 KB argument cap,
`--mode plan` never swapped for `accept-edits`.

**A bad `--agent` name fails silently.** Tested: `--agent
definitely-not-an-agent` answered normally and exited 0. There is no error
and no warning — you get a generic answer while believing you ran a
specialist. Copy the name from `agy agents` output, never type it from
memory, and treat a suspiciously generic reply as a possible typo rather than
as the agent's opinion.

**Verify its file references.** In testing, agy's reasoning was correct while
its citations pointed at paths under a directory that does not exist on this
machine. Plausible-looking `file:///` links are not evidence — open what it
cites before repeating it.

## Consensus — when disagreement is the point

Ask both the same question, one at a time, then report three things:

1. What they **agree** on.
2. Where they **disagree**, and what each one's reasoning was.
3. What each said it **could not verify**.

The disagreement is the product. Two models reaching the same answer is
weaker evidence than it feels — they share training data and failure modes.
Report the divergence explicitly rather than averaging it away, and give
your own recommendation separately.

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
