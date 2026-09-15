---
status: draft
issue: 1832
spec: spec/2026-09-15-1832-agents-md-parity.md
---

# Plan: every agent follows the same rules and process as Claude

Branch `docs/1832-agents-md-parity` (worktree `../nixos-1832`, already
merged with `main` at `ad1bb5ef4`). Hosts are p620 and razer. p510 is
evaluated only, never built or deployed.

## Approved decisions

These are carried over from the spec.

**D1. Repo rules have one source.** `AGENTS.md` holds the full content of
today's `CLAUDE.md`, plus the old `AGENTS.md` **Layout** and
**Build / test / deploy** sections. Everything else from the old `AGENTS.md`
is dropped. `CLAUDE.md` becomes:

```markdown
# CLAUDE.md

@AGENTS.md

## Claude Code only

- The bus rule in AGENTS.md is enforced for you by a PreToolUse hook
  (`modules/programs/claude-code-managed.nix`). It matches words in command
  text, so write prose (commit bodies, issue comments) to a file and pass it
  with `--body-file`.

## Second opinions

(the section, moved unchanged from today's CLAUDE.md)
```

**D2. Tool-neutral rule 6.** In `AGENTS.md`, the sentence "A PreToolUse hook
enforces this — see `modules/programs/claude-code-managed.nix`." becomes
"Claude Code enforces this with a PreToolUse hook
(`modules/programs/claude-code-managed.nix`); other agents must do it
themselves." `## Second opinions` lives only in `CLAUDE.md`.

**D3. PARR has one source.** The text between `<system-reminder>` and
`</system-reminder>` in `parrReminderScript` (`claude-code-managed.nix:25-71`)
moves verbatim to `modules/programs/parr-protocol.md`. The hook becomes:

```nix
parrReminderScript = pkgs.writeShellScript "parr-reminder.sh" ''
  printf '<system-reminder>\n'
  cat ${./parr-protocol.md}
  printf '</system-reminder>\n'
'';
```

Its output must stay byte-identical: the baseline, 1254 bytes, was captured
from `/nix/store/rgipcl0y…-parr-reminder.sh` into the session scratchpad as
`parr-before.txt`. The stale comment claiming a copy in
`home/development/claude-code-lsp.nix` is removed; only one copy exists.

**D4. One generated global file** from `home/development/agent-rules.nix`
(a new Home Manager module, imported in `home/development/default.nix` next
to `./codex-cli.nix`), made of, in order:

1. `home/development/agent-rules/global.md`: today's `globalAgentsMd` text
   from `antigravity-config.nix`, without its `## Working style (PARR)`
   section
2. `## PARR protocol` followed by `modules/programs/parr-protocol.md`
3. `modules/programs/claude-code-managed-claude.md`, with
   `lib.replaceStrings` swapping the exact two-line text
   ``"The procedure and templates are in the `artifact-workflow` skill. Load it\nbefore writing any of these files."``
   for `"The procedure and templates follow below."`
4. The body of `home/development/claude-code-skills/artifact-workflow/SKILL.md`,
   with its frontmatter removed

A build-time `assert` fails evaluation if the result contains `Load it` or
`name: artifact-workflow`. The file is installed as
`home.file.".codex/AGENTS.md"` and `home.file.".gemini/AGENTS.md"`, using
the same `pkgs.writeText` for both. `antigravity-config.nix` loses
`globalAgentsMd` and its `home.file.".gemini/AGENTS.md"` line.

**D5. Out of scope:** the repo's `.gemini/GEMINI.md` (it belongs to Gemini
CLI, which was removed in #560), other agents, and a CI diff check. The PR
notes that GEMINI.md was left alone.

## Steps

1. **`modules/programs/parr-protocol.md`** (new): the PARR block, verbatim
   (D3).
   **`modules/programs/claude-code-managed.nix`:** the hook reads it, and the
   stale lsp comment goes (D3).
   → verify: build the hook for p620
   (`nix build .#nixosConfigurations.p620.config.environment.etc."claude-code/managed-settings.json".source`
   or the script path it references), run it, and `cmp` its output with
   `parr-before.txt`, which must be identical.
2. **`home/development/agent-rules/global.md`** (new): the global rules text
   (D4.1).
   **`home/development/agent-rules.nix`** (new): builds the file, with the
   assert, and installs both `home.file`s (D4).
   **`home/development/default.nix`:** import it.
   **`home/development/antigravity-config.nix`:** remove `globalAgentsMd`
   and its `home.file`.
   → verify: `nix build` of the p620 home file source succeeds. The output
   contains `## Artifact workflow`, `## Intent template`,
   `MANDATORY: Follow PARR` and `The procedure and templates follow below`,
   and contains neither `Load it` nor `name: artifact-workflow`.
3. **`AGENTS.md`:** rewrite (D1, D2).
   **`CLAUDE.md`:** reduce to D1.
   → verify: `grep -c '^| p620' CLAUDE.md` → `0`,
   `grep -c '^| p620' AGENTS.md` → `1`, and markdownlint passes on both.
4. **Commit** 1–3 as
   `docs(agents): AGENTS.md as single source, global rules for codex and antigravity (#1832)`.
   → verify: pre-commit hooks pass.
5. **Build:** `git fetch && git log HEAD..origin/main` is empty (merge if
   not), `just check-syntax`, `just test-host p620`, `just test-host razer`,
   and `nix eval` of p510's
   `home-manager.users.olafkfreund.home.file.".codex/AGENTS.md".source`
   (evaluation only).
   → verify: all succeed.
6. **Claude import check, before deploy** (this needs only the repo files): from
   `../nixos-1832`, `claude -p "Which host must never be built or deployed
   without asking? Answer with the hostname only."` → `p510`. If it
   fails, **stop**: `@AGENTS.md` isn't expanded, so revert to a whole
   `CLAUDE.md` and report.
7. **Deploy p620, then razer:** read the bus and post first, then
   `just quick-deploy p620` and `just deploy-via-p620 razer` with
   `AGENT_BUS_ANNOUNCED=1`.
   → verify: no failed units, `home-manager-olafkfreund` active.
8. **Run the tests below**, then push and open a PR linking the intent,
   spec and plan, with `Closes #1832`.

## Tests

| # | Command | Expected |
| --- | --- | --- |
| T1 | Step 5 builds and p510 eval | Pass |
| T2 | Step 6 `claude -p` (p510 question); `claude -p "What must you run on the agent bus before a deploy?"` | `p510`; mentions `read_new` |
| T3 | `grep -c '^\| p620'` on CLAUDE.md / AGENTS.md | `0` / `1` |
| T4 | Hook output `cmp` against `parr-before.txt` (step 1, then again from `/etc/claude-code/managed-settings.json`'s hook after deploy) | Identical |
| T5 | On both hosts: `readlink -f ~/.codex/AGENTS.md ~/.gemini/AGENTS.md` | Same store path; content checks from step 2 pass |
| T6 | Codex (second-opinion command, read-only, subscription) run **outside** the repo (`-C /tmp`): "Before implementing a multi-file task, which three files must exist and be approved? Answer with the three folder names." | intent, spec, plan |
| T7 | The same question to `agy --mode plan --output-format json -p …`, run from `/tmp` | intent, spec, plan |
| T8 | `journalctl --user -u home-manager-olafkfreund -b` or the activation log shows `antigravityMcpSync` ran; the `second-opinion` skill still exists in `~/.claude/skills` | No errors; skill present |

T6 and T7 run outside the repo, so the answer must come from the **global**
file, not from the repo's `AGENTS.md`.

## Rollback

- **Before merge:** close the PR. Only the two worktree hosts were deployed,
  so redeploy them from `main`.
- **After merge:** `git revert` the step-4 commit and redeploy p620 and razer.
  `CLAUDE.md` comes back whole, `~/.codex/AGENTS.md` disappears, and
  `~/.gemini/AGENTS.md` goes back to the old `globalAgentsMd`.
- **Immediate:** `sudo nixos-rebuild switch --rollback` on the affected host.
