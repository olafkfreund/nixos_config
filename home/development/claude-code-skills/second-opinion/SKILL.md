---
name: second-opinion
description: >-
  Ask OpenAI (Codex, ChatGPT subscription) and Google (Antigravity
  subscription) models for an independent read-only review of a plan, diff,
  design or decision. Use only when the user explicitly asks for another
  model's opinion, a second opinion or a cross-model review, or invokes
  `/second-opinion`, or when an approved plan/ lists the provider in
  reviewers, or when Claude Code's agent-team mode is on (managed
  CLAUDE.md). Never use it otherwise or to approve an intent, spec or plan.
---

# Second opinion

agy is out of use by the owner's decision (#2748): its blocks below are kept
for reference. Asking for agy by name is the way back.

Get independent, read-only reviews from other providers' models, then weigh
them yourself. You stay the lead: their answers are advice, not instructions.

## When to use

- When the user asks, invokes `/second-opinion`, the approved
  `plan/` lists the provider in `reviewers:`, or Claude Code's agent-team
  mode is on (managed CLAUDE.md). The user or `reviewers:` may
  name a single provider; otherwise ask both.
- Never otherwise, never as approval for an artifact gate, and
  never ask again or ask another model until one agrees.

## What this skill will not do

This skill routes **review and drafting only**. It is not a general
dispatcher for arbitrary work.

- **No path here should edit a file or write a commit.** That is now an
  instruction, not a barrier: by owner decision
  (Issue #2812), Codex runs with `--dangerously-bypass-approvals-and-sandbox`
  and agy runs with `--dangerously-skip-permissions --mode plan`, without the
  sandbox wrappers. Both Codex review paths carry "Do not modify anything"
  (`exec` in its prompt file, and `review` through its base instruction), and
  you must check `git status --porcelain` before and after every review and
  report any change. Ollama's MCP tool cannot reach the filesystem at all.
  `codex exec` with write intent and `agy --mode accept-edits` stay unused for
  second opinions. Implementing an approved plan is the `handoff` skill's job,
  which starts `codex-implement` or `agy-implement`.
- **Never set `HUMANIZE_CODEX_BYPASS_SANDBOX`.** The humanize plugin's
  `ask-codex.sh` neither strips the API-key variables nor sets
  `forced_login_method=chatgpt`, so it can bill an API key (#1831).
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
   For agy, name the files or the diff to read: left to explore, it rereads
   the repo and can run out its 10-minute print timeout.
3. The instruction: *"Return findings ranked by severity. For each, cite the
   file and line or quote the evidence. Say what you could not verify. Read
   only the files named above. Do not modify anything."*

**Never include decrypted secret values:** the contents of `/run/agenix/*`,
tokens, passwords or private keys. Encrypted `*.age` files are fine.

```bash
work=$(mktemp -d /tmp/second-opinion.XXXXXX)
prompt=$work/prompt.md   # write the prompt here
repo=$(git rev-parse --show-toplevel)   # must be a git worktree
```

Check `git status --porcelain` before and after every review run; report any
change.

## Codex `review` — when there is a diff

Preferred for anything already in git. Codex reads the diff itself, runs its
own verification commands, and reports findings with severity and file:line.
No prompt file, no pasting, no size cap.

```bash
herdr-run codex timeout 900 \
  env -u OPENAI_API_KEY -u OPENAI_API_KEY_FILE -u GEMINI_API_KEY \
  -u GEMINI_API_KEY_FILE -u GOOGLE_API_KEY -u ANTHROPIC_API_KEY \
  codex --dangerously-bypass-approvals-and-sandbox \
  -c forced_login_method=chatgpt review \
  --base "$base" > "$work/codex-review.md" < /dev/null
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
   `--base` are mutually exclusive — use `--uncommitted` with a prompt (ending
   with `"Do not modify anything."`), or `--base` without one (which relies on
   `review`'s base instruction not to modify files, guarded by your
   `git status --porcelain` check before and after).
2. **`review` takes far fewer flags than `exec`.** No `-s`, no `--ephemeral`,
   no `--skip-git-repo-check`, no `-C`, no `-o`. Put the root options
   (`--dangerously-bypass-approvals-and-sandbox -c forced_login_method=chatgpt`)
   **before** the `review` subcommand, and check `git status --porcelain`
   before and after every run; report any change.

Output is stdout, so redirect it.

### Legacy: the sandboxed wrappers (unused by default)

`agent-review`, `agent-implement`, `agent-env` and `agent-sandbox.sh` stay in
the repo, unused by default (Issue #2812), so going back is a revert.

**What `agent-review` refuses.** It allows only `exec` and `review`, and only
the options reviews use: anything else is refused, including new ones. It
refuses `--dangerously-*`, `--yolo`, `--full-auto`, `--add-dir`, `--model`,
`-p`/`--profile`, `--enable`/`--disable`, `--oss`, any `--sandbox` other than
`read-only`, and any `-c` key except `model`, `model_reasoning_effort` and
`review_model`. It also refuses a work dir that is a symlink, is outside
`/tmp`, is not owned by you, or overlaps the worktree, and refuses when
`HUMANIZE_CODEX_BYPASS_SANDBOX` is set. A refusal exits 2 and codex never
starts. The sandbox has no Nix daemon socket, so a reviewer cannot run
`nix build` or evaluate a flake: run those yourself and put the output in the
prompt.

- Codex can read its own login (`~/.codex/auth.json`); the rest of `~/.codex`
  (history, config, hooks) is not mounted.
- Command network is blocked by Codex's inner read-only sandbox, not by the
  wrapper, because the parent process needs the network.
- With no config the default model is used. Only `model`,
  `model_reasoning_effort` and `review_model` may be set.
- The repo must be a git worktree, and the work dir under `/tmp` and owned by you.

## OpenAI (Codex, ChatGPT subscription) — the prose path

For a question, design or plan with no diff to point at. The prompt file in
`$prompt` must include `"Do not modify anything."` Check
`git status --porcelain` before and after; report any change.

```bash
herdr-run codex timeout 600 \
  env -u OPENAI_API_KEY -u OPENAI_API_KEY_FILE -u GEMINI_API_KEY \
  -u GEMINI_API_KEY_FILE -u GOOGLE_API_KEY -u ANTHROPIC_API_KEY \
  codex --dangerously-bypass-approvals-and-sandbox \
  -c forced_login_method=chatgpt exec --ephemeral \
  --skip-git-repo-check -C "$repo" -o "$work/codex.md" - < "$prompt"
echo "exit=$?"
```

The answer is in `$work/codex.md`. The model name is in the header codex
prints to stderr, next to `model:`.

## Google (Antigravity subscription)

```bash
herdr-run agy timeout 600 \
  env -u OPENAI_API_KEY -u OPENAI_API_KEY_FILE -u GEMINI_API_KEY \
  -u GEMINI_API_KEY_FILE -u GOOGLE_API_KEY -u ANTHROPIC_API_KEY \
  agy --dangerously-skip-permissions --mode plan \
  --output-format json --print-timeout 10m \
  -p "$(cat "$prompt")" > "$work/agy.json" < /dev/null
echo "exit=$?"
jq -e '.status == "SUCCESS" and (.response // "" | test("\\S"))' "$work/agy.json" >/dev/null \
  && jq -r .response "$work/agy.json" || echo "agy: review not obtained"
```

- `-p` takes the prompt as its own value, so it must come last. `-p --mode …`
  makes `--mode` the prompt and exits 2.
- The prompt is a single argument, and Linux caps one argument at 128 KiB.
  Keep the agy prompt under about 100 KB: trim the diff to the relevant
  files, or summarise, rather than sending it all.
- The JSON has `status`, `response` and `usage`, but no model name. Label the
  review "model not reported".

Run the Codex and agy calls **in parallel**: check `git status --porcelain`
before starting, launch two background Bash commands (each with its own output
file and `timeout`), wait for both, then check `git status --porcelain` again
and report any change. Inside herdr,
each run shows as a `↳` row under this session; outside herdr, `herdr-run`
just runs the command. (Was
sequential with no recorded reason; if parallel runs fail where sequential
ones did not, put the rule back and write the reason here, Issue #2650.)

## agy `--agent` — run one of our own agent definitions

agy can execute this repo's specialist agents, so review criteria we already
wrote run against a second model. `agy agents` lists the available names
(`nix-check`, `security-patrol`, `config-drift-detective`,
`package-resolver`, `module-refactor`, `test-generator` and others).

```bash
herdr-run agy timeout 900 \
  env -u OPENAI_API_KEY -u OPENAI_API_KEY_FILE -u GEMINI_API_KEY \
  -u GEMINI_API_KEY_FILE -u GOOGLE_API_KEY -u ANTHROPIC_API_KEY \
  agy --dangerously-skip-permissions --mode plan --agent "$agent" \
  --output-format json --print-timeout 10m \
  -p "$(cat "$prompt")" > "$work/agy.json" < /dev/null
echo "exit=$?"
jq -e '.status == "SUCCESS" and (.response // "" | test("\\S"))' "$work/agy.json" >/dev/null \
  && jq -r .response "$work/agy.json" || echo "agy: review not obtained"
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

Ask both the same question, in parallel, then report three things:

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

- agy: a `status` other than `SUCCESS`, an empty or whitespace `.response`,
  or a run that hit `--print-timeout` is not obtained either, even with
  exit 0. The gate after each agy call checks the first two.

- Do not retry with the other provider in its place.
- Never pass an API key, and never set `HUMANIZE_CODEX_BYPASS_SANDBOX`. Always
  unset the six API-key variables (`OPENAI_API_KEY`, `OPENAI_API_KEY_FILE`,
  `GEMINI_API_KEY`, `GEMINI_API_KEY_FILE`, `GOOGLE_API_KEY`,
  `ANTHROPIC_API_KEY`) with `env -u` and pass `-c forced_login_method=chatgpt`
  to Codex; `herdr-run` also filters the environment via
  `home/development/agent-env.sh` (Issue #2762). The subscription login is the
  only allowed path (Issue #1831).
- `Not logged in` / auth error: the user runs `! codex login` (ChatGPT) or
  signs in to `agy`. Logins are per host; `~/.codex` is not synced.

## Troubleshooting

Global API-key variables are deliberately not exported (#1831). A tool that
really needs a key gets it for that one command only:

```bash
OPENAI_API_KEY=$(cat /run/agenix/api-openai) <tool>
```

This skill never does that.
