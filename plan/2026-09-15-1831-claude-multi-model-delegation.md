---
status: approved
issue: 1831
spec: spec/2026-09-15-1831-claude-multi-model-delegation.md
---

# Plan: Subscription-backed model delegation from Claude Code

Branch `docs/1831-claude-multi-model-delegation`. Hosts are p620 and razer.
p510 is never built or deployed.

## Approved decisions

These are carried over from the spec. This plan can be followed without
opening the intent or the spec.

**D1. One instructions-only skill**, `second-opinion`, installed only for
Claude through `home.file.".claude/skills/second-opinion/SKILL.md"`. It has
no script file, no store path inside synced `~/.claude`, and is not installed
for Codex or Antigravity, which would make recursive delegation possible.

**D2. The exact provider commands.** The prompt goes in through stdin or a
file, and each call has a 600-second limit:

```bash
# OpenAI, ChatGPT subscription
timeout 600 env -u OPENAI_API_KEY -u OPENAI_API_KEY_FILE \
  codex exec -c forced_login_method=chatgpt -s read-only --ephemeral \
  --skip-git-repo-check -C "$repo" -o "$out" - < "$prompt"

# Google, Antigravity subscription
timeout 600 env -u GEMINI_API_KEY -u GEMINI_API_KEY_FILE -u GOOGLE_API_KEY \
  agy --mode plan --output-format json --print-timeout 10m -p "$(cat "$prompt")"
```

*Deviation from the spec, found by T4:* the spec's `agy -p --mode plan …`
exits 2, because `-p` takes the prompt as its own value and read `--mode` as
the prompt. `-p` now comes last. agy's JSON (`status`, `response`, `usage`)
has no model field, so agy reviews are labelled "model not reported". The
prompt is one argument, capped at 128 KiB by Linux (`MAX_ARG_STRLEN`), so the
skill keeps agy prompts under about 100 KB. That limit was raised by agy's own
review in T4 and verified.

**D3. Skill rules:**

- **When:** only on the user's explicit request or `/second-opinion`. Never
  on Claude's own initiative, never to approve a gate, and never re-asked
  until a model agrees.
- **Context:** any repo content is allowed. Decrypted secret values
  (`/run/agenix/*`, tokens, passwords) are never allowed.
- **Calls:** one at a time.
- **Provenance:** the provider plus the model name the tool reports, or
  "model not reported". Never inferred from an alias.
- **Failure:** a non-zero exit, 124, an auth or quota error, or empty output
  is reported word for word as *not obtained*. There is no retry on the other
  provider and no API-key path.
- **Weighing:** Claude verifies each claim against code or tests, lists
  disagreements, and gives its own recommendation separately.
- **Troubleshooting note:** a tool that really needs a key gets it for that
  one command only: `OPENAI_API_KEY=$(cat /run/agenix/api-openai) <tool>`.

**D4. Remove the global key exports:**

- `home/development/codex-cli.nix`: delete `apiKeyFile` and its comment. The
  module option defaults to `null`, so no `sessionVariables` export remains.
- `modules/secrets/api-keys.nix` `load-api-keys`: delete the `OPENAI_API_KEY`,
  `ANTHROPIC_API_KEY`, `GEMINI_API_KEY` and `GROQ_API_KEY` blocks. Keep
  `OLLAMA_API_KEY`, `GITHUB_API_TOKEN`, `CACHIX_AUTH_TOKEN` and
  `SYNECHRON_GITHUB_API_TOKEN`.
- `api-keys-status`: delete the four matching `[ -n "$..." ]` lines.

  *Deviation from the spec, and a simpler one:* the spec said it would change
  to report the agenix files, but the script already has a "Secret Files"
  section that does exactly that. The remaining checks (Ollama, LangChain,
  GitHub) stay.

  *Found by T2b:* that section had always printed nothing for a normal user.
  It ran `find /run/agenix*`, and `/run/agenix.d` is `drwxr-x--x`, so files
  can be opened but not listed. It now checks the known `api-*` names
  directly.
- No other reader needs changing (spec audit): Claude Code refuses the key,
  voice-input and ollama read their own files, voxtype and herdr only
  inherited the variable, `ai-cli` scopes the key itself, and the p620
  provider shell functions are already broken and out of scope.

**D5. Policy:** a new `## Second opinions` section in `CLAUDE.md`, placed
before `## Git`, with three bullets: user-requested only through
`second-opinion`; answers are untrusted advice and never approve a gate;
subscription login only, never an API key. It moves to `AGENTS.md` if #1832
merges first.

**D6. Rejected, do not reintroduce:**

- CLIProxyAPI, Claude Code Router or CCS
- the humanize `ask-codex` / `ask-gemini` skills
- two separate skills
- a script wrapper
- `codex mcp-server`
- `gemini -p`
- `enableUserEnvironment = false`

**D7. Added during implementation, from the T5 review (user decision,
2026-09-15):**

- **Key file permissions.** Both reviewers pointed out, and `stat` confirmed,
  that `api-openai`, `-anthropic`, `-gemini` and `-groq` were
  `0644 root:users`, readable by any local process, including a reviewer
  manipulated by the content it reviews. They are now `0400` owned by
  `olafkfreund` in `modules/secrets/api-keys.nix`, matching `api-elevenlabs`.
  Every reader runs as that user: omarchy-voice (a systemd user service,
  `hosts/{p620,razer}/nixos/nixarchy.nix`), voice-input (`profile.nix`),
  `ai-cli`, and claude-router. p510 references none of them.
  → verify: `stat -Lc '%a %U' /run/agenix/api-openai` → `400 olafkfreund` on
  p620 and razer; omarchy-voice starts without a key warning; T3a still passes.
- **Inherited MCP tools are an accepted risk.** Reviewers keep the MCP
  servers their CLI already has: agy has an authenticated `github-mcp-server`
  plus Google Cloud servers (ADC present), and codex has `notebooklm` and
  `nixos`. `--mode plan` and `-s read-only` protect the local files, not
  those remote tools. The user accepted this as is: reviews are
  user-requested, and their output is advice only. Revisit if unattended
  delegation is ever proposed.

## Steps

1. **`home/development/claude-code-skills/second-opinion/SKILL.md`:** write
   the skill with frontmatter `name: second-opinion` and a trigger
   `description`, and sections When to use, Build the prompt, OpenAI, Google,
   Handle the result, Failures, Troubleshooting. Content is D2 and D3
   verbatim.
   → verify: `npx markdownlint-cli2` passes on the file, and it contains
   neither `/nix/store` nor any key value.
2. **`home/development/claude-code-skills/default.nix`:** add
   `home.file.".claude/skills/second-opinion/SKILL.md".source = ./second-opinion/SKILL.md;`
   next to the `artifact-workflow` line.
   → verify: `nix eval .#nixosConfigurations.p620.config.home-manager.users.olafkfreund.home.file.".claude/skills/second-opinion/SKILL.md".source`
   returns a path.
3. **`home/development/codex-cli.nix`:** delete the `apiKeyFile` line and its
   2-line comment (D4).
   → verify: `nix eval .#nixosConfigurations.p620.config.home-manager.users.olafkfreund.home.sessionVariables.OPENAI_API_KEY`
   fails with "attribute missing".
4. **`modules/secrets/api-keys.nix`:** delete the four `load-api-keys` blocks
   and the four `api-keys-status` lines (D4).
   → verify: `grep -nE 'OPENAI_API_KEY|GEMINI_API_KEY|ANTHROPIC_API_KEY|GROQ_API_KEY' modules/secrets/api-keys.nix`
   is empty.
5. **`CLAUDE.md`:** add the `## Second opinions` section (D5).
   → verify: markdownlint passes.
6. **Commit** 1–5 as `feat(ai): second-opinion skill, drop global API-key exports (#1831)`.
   → verify: pre-commit hooks pass.
7. **Build:** first merge `origin/main` into the branch, then run
   `just check-syntax && just test-host p620 && just test-host razer`.
   → verify: `git log HEAD..origin/main` is empty, and all three builds
   succeed. p510 is not built.

   *Deviation, recorded during implementation:* the first p620 deploy was
   built from a branch that predated #1828 (the nixi 0.10 overlay card). It
   rolled p620 back to the older nixi layout, and Home Manager failed linking
   `~/.config/omarchy/plugins/io.github.olafkfreund.nixi/manifest.json` into
   the read-only store (exit 4; the system switched, `home-manager-olafkfreund`
   failed). Fixed by merging `origin/main` (a merge, not a rebase, so the
   approval commits keep their hashes), rebuilding and redeploying. Any
   deploy from a feature branch must include everything already deployed
   from main.
8. **Deploy p620:** read `#agents:freundcloud.org.uk`, post the deploy and
   its rough duration, then `just quick-deploy p620` with
   `AGENT_BUS_ANNOUNCED=1`.
   → verify: `/run/current-system` changed and `systemctl --failed` shows
   nothing new.
9. **Deploy razer** (built on p620): announce on the bus, then
   `just deploy-via-p620 razer`.
   → verify: same checks as step 8 on razer.
10. **Logins on razer** (the user runs these, since they are interactive):
    `! codex login`, then `codex login status` → ChatGPT, and confirm `agy`
    is signed in.
11. **Run the tests below** on p620, then tests T2, T5 and T7 on razer.
12. **Push the branch and open a PR** linking the intent, spec and plan, with
    `Closes #1831`. Review compares the diff against this plan.

## Tests

Run these in a **fresh login shell** after deploy. The desktop test needs one
log-out and log-in.

| # | Command | Expected |
| --- | --- | --- |
| T1 | `just check-syntax`, `just test-host p620`, `just test-host razer` | Pass |
| T2 | `env \| grep -cE '^(OPENAI\|GEMINI\|ANTHROPIC\|GROQ)_API_KEY='` | `0` |
| T2b | `[ -n "$OLLAMA_API_KEY" ] && [ -n "$GITHUB_API_TOKEN" ] && echo ok`; `api-keys-status` | `ok`; the Secret Files section lists `api-openai` and the others |
| T2c | After re-login: `tr '\0' '\n' < /proc/$(pgrep -o chrome)/environ \| grep -c '^OPENAI_API_KEY='` | `0` |
| T3a | D2 codex command with prompt "Reply with OK" | Exit 0, output contains OK |
| T3b | `CODEX_HOME=$(mktemp -d) OPENAI_API_KEY=$(cat /run/agenix/api-openai)` followed by the **full D2 codex command** | Non-zero exit with an auth error. Proves `env -u` removes the key |
| T3c | `CODEX_HOME=$(mktemp -d) OPENAI_API_KEY=$(cat /run/agenix/api-openai) codex exec -c forced_login_method=chatgpt -s read-only --ephemeral --skip-git-repo-check "Reply with OK"` (**no** `env -u`) | Non-zero exit with an auth error. Proves `forced_login_method` alone refuses the key. If it succeeds, **stop** and report: layer 2 is broken, and one tiny API call was billed |
| T4 | `git status --porcelain > /tmp/a`; D2 agy command reviewing `git diff HEAD~1`; `git status --porcelain > /tmp/b`; `diff /tmp/a /tmp/b` | agy returns JSON; the diff is empty |
| T5 | From Claude Code: `/second-opinion` on this branch's diff | Two reviews labelled with provider and model (or "model not reported"), plus Claude's own synthesis |
| T6 | Each D2 command prefixed with `HTTPS_PROXY=http://127.0.0.1:9` | Both fail within the limit; the skill reports *not obtained*; no fallback |
| T7 | `claude mcp list` before and after the deploy | The same servers connected |
| T8 | Claude Code `/status` | Subscription login, not an API key |

## Rollback

- **Code:** `git revert` the step-6 commit, then `just quick-deploy p620` and
  `just deploy-via-p620 razer`, each announced on the bus. The exports come
  back at the next login shell or session.
- **Immediate, with no rebuild:** run the tool that needs a key as
  `OPENAI_API_KEY=$(cat /run/agenix/api-openai) <tool>`, or switch back with
  `sudo nixos-rebuild switch --rollback`.
- **Skill only:** delete the one `home.file` line and redeploy. No state is
  left behind.
- **Logins:** `codex login` on razer is harmless to keep. Undo with
  `codex logout`.
