---
status: draft
issue: 1831
intent: intent/2026-09-15-1831-claude-multi-model-delegation.md
---

# Spec: Subscription-backed model delegation from Claude Code

## Design

There are three parts. None of them adds a service, a port or a package.

### 1. The `second-opinion` skill

One skill, `home/development/claude-code-skills/second-opinion/SKILL.md`,
installed the same way as `artifact-workflow` (`claude-code-skills/default.nix:48`):

```nix
home.file.".claude/skills/second-opinion/SKILL.md".source = ./second-opinion/SKILL.md;
```

The skill is instructions only, with no script file. Claude runs the commands
below through its Bash tool, so no store path or helper script lands in the
synced `~/.claude`. It has two parts:

- **When to use it:** only when the user asks for another model's opinion, or
  invokes `/second-opinion`. Never on Claude's own initiative, never to
  approve an artifact gate, and never re-asked until a model agrees.
- **How to call it:** Claude builds the prompt from the task, the context it
  selects (diff, plan or file excerpts; any repo content is allowed) and an
  instruction to return findings with evidence. Decrypted secret values are
  never included. The prompt goes in through stdin.

OpenAI, through the ChatGPT subscription:

```bash
out=$(mktemp -d)/codex.md
timeout 600 env -u OPENAI_API_KEY -u OPENAI_API_KEY_FILE \
  codex exec -c forced_login_method=chatgpt -s read-only --ephemeral \
  --skip-git-repo-check -C "$repo" -o "$out" - < prompt.md
```

Google, through the Antigravity subscription:

```bash
timeout 600 env -u GEMINI_API_KEY -u GEMINI_API_KEY_FILE -u GOOGLE_API_KEY \
  agy -p --mode plan --output-format json --print-timeout 10m "$(cat prompt.md)"
```

How results are handled:

- **Provenance:** Claude reports which provider answered. It includes the
  model name from codex's output header or agy's JSON when the tool gives
  one, and otherwise writes "model not reported". It never guesses from an
  alias.
- **One call at a time:** a second request waits for the first to finish.
- **Failure:** a non-zero exit, exit code 124 (timeout), an auth or quota
  error, or empty output is reported to the user word for word, and the
  review is marked *not obtained*. There is no retry on the other provider
  and no API-key path.
- **Weighing the answer:** Claude checks each claim against the code or tests
  before relying on it, lists points of disagreement, and states its own
  recommendation separately.

The skill is installed only for Claude (`~/.claude/skills`), unlike `gog`,
which also goes to `~/.codex` and `~/.gemini`. Installing it for Codex and
Antigravity as well would let them call each other, which the intent rules
out as recursive delegation.

### 2. Removing the global API-key exports

Two mechanisms put the keys into the environment today:

| Source | Effect | Change |
| --- | --- | --- |
| `home/development/codex-cli.nix:11` sets `apiKeyFile`, and `codex-cli/module.nix:47-48` turns it into home-manager `sessionVariables` | `OPENAI_API_KEY` is set across the **whole graphical session**. On p620 it appears in Chrome, xdg-desktop-portal, voxtype, herdr, wl-paste and more | Delete the `apiKeyFile` line and its comment. The option stays with its default `null`, so nothing is exported |
| `modules/secrets/api-keys.nix:218-240`: `load-api-keys`, evaluated by the bash and zsh `interactiveShellInit` (`:289-301`) | Every interactive shell, and everything started from one (Claude Code, its MCP servers, python, uv), gets all five provider keys | Remove the `OPENAI_API_KEY`, `GEMINI_API_KEY`, `ANTHROPIC_API_KEY` and `GROQ_API_KEY` blocks. Keep `OLLAMA_API_KEY`, `GITHUB_API_TOKEN`, `CACHIX_AUTH_TOKEN` and `SYNECHRON_GITHUB_API_TOKEN` |

`api-keys-status` (`:266-270`) checks the variables. It changes to report
whether each `/run/agenix/api-*` file is readable, so it doesn't claim the
keys are "not available" once the exports are gone.

**Audit of readers** (the intent requires this before removal):

| Reader | How it gets a key | Affected? |
| --- | --- | --- |
| Claude Code | Subscription login. `~/.claude.json` has `customApiKeyResponses.rejected = 2` and `approved = 0`, so it has always refused the exported key | No. Removing `ANTHROPIC_API_KEY` removes the risk of it being accepted by mistake |
| `programs.voice-input` (`home/applications/voice-input.nix:43-48`) | `$(cat apiKeyFile)` at request time | No |
| voxtype | Its own `remote_api_key` / `VOXTYPE_WHISPER_API_KEY` | No |
| herdr auto-title plugin | Never reads any key (it only inherits the variable) | No |
| ollama daemon | Its own `EnvironmentFile` (`modules/services/ollama.nix:215-220`) | No, and `OLLAMA_API_KEY` is kept for the `ollama` CLI |
| `ai-cli` unified client (`modules/ai/providers/unified-client.nix:183-211`) | Exports the key inside its own script process from `/run/agenix/*` | No, it is already scoped to that one program |
| `openai-chat`, `gemini-*` and `anthropic-*` shell functions (`modules/ai/providers/{openai,gemini,anthropic}.nix`, p620 only) | Read `/run/secrets/api-*`, **which does not exist on p620**, so they already fail with "key not found" | No regression. Fixing them is out of scope |
| MCP servers started by Claude (github, git, fetch, mcp-nixos, notebooklm, pfactory…) | None of them is configured to use a provider key; they inherit the variables from the shell | Checked after deploy: `claude mcp list` must still show them all connected |

**Remaining risk:** a tool nobody declared that reads `OPENAI_API_KEY` from
the environment, such as an ad-hoc `pip install` script. Recovery is one
line, `OPENAI_API_KEY=$(cat /run/agenix/api-openai) <tool>`, which is
documented in the skill's troubleshooting note.

### 3. Consultation policy

Add a short **Second opinions** paragraph to `CLAUDE.md`, or to `AGENTS.md`
if #1832 merges first. It says:

- Consult only on the user's request, through `second-opinion`.
- External answers are untrusted advice, never gate approval.
- Subscription only; never an API key.

### Hosts

- **p620 and razer:** both import `codex-cli.nix` through `home/development/default.nix`,
  and both enable `secrets.apiKeys.enableUserEnvironment`.
- **razer** additionally needs a one-time `codex login` (`~/.codex` is not
  synced) and a check that `agy` is signed in.
- **p510** shares `api-keys.nix`, so its shells lose the same four exports at
  its next deploy. It runs no codex or agy workflow, so nothing there depends
  on them. It is not built or deployed as part of this work.

## Alternatives rejected

- **CLIProxyAPI, Claude Code Router, CCS:** they replay subscription OAuth
  through a third-party server (intent constraint).
- **The humanize `ask-codex` / `ask-gemini` skills as they are:**
  - `--full-auto` gives the reviewer a writable workspace, and a bypass
    variable disables the sandbox.
  - Google Search is forced into every prompt.
  - They call the mise-installed `gemini` (nixarchy#707).
  - The plugin is third-party and updates outside this repo, so a fix there
    would not stay pinned.
- **Two separate skills (one per provider):** the rules on when to use them,
  how to weigh answers and how failures work are identical. One file keeps
  them from drifting apart.
- **A script wrapper in the skill:** it would need a store path or an
  executable inside synced `~/.claude`. Plain commands Claude runs itself
  need neither.
- **`codex mcp-server` as an MCP tool:** it runs permanently in every Claude
  session and has more reach than a one-shot read-only call. Deferred by the
  intent.
- **`gemini -p` instead of `agy -p`:** `gemini` comes from mise today and
  fails config validation in this repo (`.gemini/settings.json`). `agy` is
  declared in the system config (`hosts/{p620,razer}/configuration.nix`,
  `ai.antigravity-cli`).
- **Setting `enableUserEnvironment = false`:** that would also drop the
  GitHub, Cachix, Synechron and Ollama tokens, which aren't part of this
  change.
- **Keeping the key exports and relying only on the per-call `env -u`:** the
  user decided to remove them.

## Risks

| Risk | Where | Mitigation |
| --- | --- | --- |
| `forced_login_method=chatgpt` isn't honoured by a future codex, or agy reads a key from another source | p620, razer | Verification test 3 removes the ChatGPT login and requires the call to *fail* |
| An undeclared tool loses its key | p620, razer, and p510 at its next deploy | Audit above, the documented one-line recovery, and `api-keys-status` still showing the files |
| Running processes keep the old variables until the next login | p620, razer | Expected. Verify in a fresh login shell, and log out and in once after deploy |
| agy's `--mode plan` still allows reading files outside the repo, or shell tools | p620, razer | Its plan mode is read-only by design, but the spec doesn't claim more. Test 4 checks the checkout is untouched. The reviewer's output is only advice |
| A reviewer's quota runs out mid-task | p620, razer | Reported as "not obtained", with no fallback |
| razer rebuild load | razer | Home-manager and text changes only, no package builds. Build through p620 if needed (`just deploy-via-p620 razer`) |

## Verification

**1. Evaluation and build**

- `just check-syntax`
- `just test-host p620`
- `just test-host razer`
- p510 is not built.

**2. No keys left in the environment** (after deploy, in a fresh login shell
on each host)

- `env | grep -cE '^(OPENAI|GEMINI|ANTHROPIC|GROQ)_API_KEY='` → `0`.
- `OLLAMA_API_KEY` and `GITHUB_API_TOKEN` are still set.
- `api-keys-status` lists the agenix files.
- After logging out and back in, `grep -c OPENAI_API_KEY /proc/$(pgrep -o chrome)/environ` → `0`.

**3. Subscription proof, codex** (on p620)

- `codex login status` → "Logged in using ChatGPT", and the one-line prompt
  "reply OK" succeeds through the skill's command.
- Then, with `CODEX_HOME=$(mktemp -d)` (no login) **and** `OPENAI_API_KEY`
  exported into that one command, the same command must **fail** with an auth
  error. That proves `env -u` plus `forced_login_method` never uses the key.

**4. Subscription proof and read-only check, Google** (on p620)

- The skill's `agy` command returns JSON for "reply OK".
- A review of a small diff leaves `git status --porcelain` identical before
  and after.

**5. End to end** (p620, then razer after its `codex login`)

- From Claude Code, `/second-opinion` on a small real diff returns both
  reviews, labelled with their provider and model, and Claude's own synthesis.

**6. Failure handling**

- Each provider command runs with `HTTPS_PROXY=http://127.0.0.1:9` (a dead
  proxy, scoped to that one command, so the host's network is never touched).
  The skill reports both reviews as *not obtained* within the timeout, and
  Claude carries on.

**7. No regressions**

- `claude mcp list` shows the same servers connected as before the change.
- Claude Code `/status` still shows the subscription login.
