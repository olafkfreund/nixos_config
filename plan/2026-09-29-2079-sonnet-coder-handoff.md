---
status: draft
issue: 2079
spec: spec/2026-09-29-2079-sonnet-coder-handoff.md
---

# Plan: Opus plans and reviews, a Sonnet 5.5 coder implements approved plans

## Approved decisions

These are copied from the approved spec, so this plan can be implemented
without opening the intent or the spec.

- **Delivery.** Everything ships through
  `modules/programs/claude-code-managed.nix`, which p620, razer and p510
  already import. Nothing is written into `~/.claude`, because Syncthing
  syncs it.
- **The `coder` agent** is installed at
  `/etc/claude-code/.claude/agents/coder.md`, the managed location. Its
  frontmatter:
  - `model: sonnet`, an alias that is Sonnet 5.5 today;
  - `tools: Read, Edit, Write, Grep, Glob, Bash`, so no Agent tool;
  - a PreToolUse hook on Bash that runs the coder guard.
- **The coder's standing instructions:**
  1. Work from the approved `plan/` only.
  2. Do one step per message, and report the result of the step's check
     command as evidence.
  3. Never commit. Report the changed files and any deviation from the
     plan.
  4. After two failed attempts at the same step, hand the step back.
- **The coder guard** has no bypass. It blocks:
  - deploy and activation: `nixos-rebuild`, `nh os`,
    `switch-to-configuration`, `nhs`, and the `just` deploy recipes;
  - store GC and optimise, reboot and poweroff;
  - `systemctl` start, stop and restart;
  - `git commit`, `push`, `checkout`, `switch`, `reset --hard` and `stash`.
- **The rule** is a closing section,
  `## Model split (Claude Code only)`, in the managed CLAUDE.md:
  - Hand off at 3 or more file-editing steps, or 3 or more files.
    Otherwise Opus implements.
  - One coder per task. Each later step goes to the same agent through
    `SendMessage`.
  - Review is done by a fresh agent with `model: "opus"`, given only the
    plan path and `git diff`.
  - A step the coder returns is finished by the main session.
  - The PR notes which steps the coder implemented.
  - It applies only to committed, approved `plan/` files.
- **Codex and Antigravity don't get it.** `agent-rules.nix` cuts the
  managed policy at that heading, and an assert fails evaluation if
  `coder` appears in the generated text.
- **The plan template** step line becomes
  `<file>:<lines>: <change> → verify by <command>`, followed by a
  `Traps:` line.
- **Fallback.** If Claude Code does not load managed agents, a copy is
  seeded into `~/.claude/agents/` by a home-manager activation step, only
  when the file is missing.
- **Measuring.** `/usage` before and after is recorded in the PRs of the
  first five tasks that hand off.

This plan has six file-editing steps, which is above the handoff
threshold. Opus implements it anyway, because the `coder` agent does not
exist until this change is deployed.

## Steps

1. `modules/programs/claude-code-coder-agent.md` (new file): write the agent
   definition. The frontmatter is as above, with the hook command written as
   the literal placeholder `@guard@`. The body is the four standing
   instructions, in the calm style of #2062 (no MUST or CRITICAL). The
   `description:` says to start it only after `plan/` is
   `status: approved`, and to reuse the same agent for the whole task.
   → verify by `grep -c '@guard@' modules/programs/claude-code-coder-agent.md`
   printing `1`.
   Traps: this is a normal markdown file. The pre-push markdownlint lints
   the whole file (MD025 and MD046). Do not start a line with `#<number>`,
   because the formatter turns it into a heading.

2. `modules/programs/claude-code-managed.nix`, after `deployGuardScript`
   (it ends around line 294): add `coderGuardScript`. Use the same shape as
   `deployGuardScript` (lines 268–294):
   - read `.tool_input.command` with `jq`;
   - match with `grep -qE` against one alternation list (the deploy verbs,
     `nix-collect-garbage`, `nix store gc|optimise`, `reboot`, `poweroff`,
     `systemctl [^|;]*(start|stop|restart)`, and
     `git [^|;]*(commit|push|checkout|switch|stash|reset[[:space:]]+--hard)`);
   - on a match, print the reason to stderr and `exit 2`;
   - otherwise `exit 0`.

   It has no bypass variable.
   → verify by `just check-syntax`.
   Traps: do not put `\b` next to an alternation group. GNU `grep -E`
   silently fails to match it, which is why `deployGuardScript` avoids it
   (see its comment). Test the pattern against real command strings.

3. `modules/programs/claude-code-managed.nix`, in the `let` block next to
   the new script: add

   ```nix
   coderAgent = pkgs.writeText "coder.md" (builtins.replaceStrings
     [ "@guard@" ] [ "${coderGuardScript}" ]
     (builtins.readFile ./claude-code-coder-agent.md));
   ```

   Then, inside `config = lib.mkIf cfg.enable {` (line 943), below the
   `environment.etc."claude-code/CLAUDE.md"` line (951), add
   `environment.etc."claude-code/.claude/agents/coder.md".source = coderAgent;`
   with a one-line comment that names #2079.
   → verify by
   `nix eval --raw .#nixosConfigurations.p620.config.environment.etc."claude-code/.claude/agents/coder.md".source`
   pointing at a store file whose hook command is a `/nix/store/…` path,
   not `@guard@`.
   Traps: none.

4. `modules/programs/claude-code-managed-claude.md`, at the end of the file
   (after line 30): append `## Model split (Claude Code only)`, holding the
   rule bullets from the approved decisions. Keep it under about 15 lines.
   This file loads into every session in every repo, so every line costs
   context everywhere.
   → verify by `tail -20 modules/programs/claude-code-managed-claude.md`.
   Traps: the section has to stay last. Step 5 cuts everything from the
   heading onwards, so anything added after it later would also be dropped
   from the Codex and Antigravity rules.

5. `home/development/agent-rules.nix`, line 7 (`managedPolicy = …`): wrap
   the value so it stops at the heading, with
   `lib.head (lib.splitString "\n## Model split (Claude Code only)" (builtins.readFile …))`.
   Then add to `agentsMd` (next to the asserts at lines 29–32):

   ```nix
   assert lib.assertMsg (!lib.hasInfix "coder" text)
     "agent-rules: the Claude-only model-split section leaked into the Codex/Antigravity rules";
   ```

   → verify by `just check-syntax`, then build the generated Codex rules
   and count `coder` in them, expecting `0`:

   ```bash
   out=$(nix build --no-link --print-out-paths \
     '.#nixosConfigurations.p620.config.home-manager.users.olafkfreund.home.file.".codex/AGENTS.md".source')
   grep -c coder "$out"
   ```

   Traps: `coder` does not appear anywhere in the generated rules today
   (checked against `agent-rules/*.md`, `parr-protocol.txt`, the managed
   policy and `SKILL.md`), so the assert cannot fire falsely today.

6. `home/development/claude-code-skills/artifact-workflow/SKILL.md`,
   line 117 (the plan template's step line): replace
   `1. <file>: <change> → verify by <check>` with
   `1. <file>:<lines>: <change> → verify by <command>` and add a following
   line, `Traps: <repo rules that apply, or "none">`. Also add one
   sentence under "Rules": a plan handed to a coder must be implementable
   without the planner's memory.
   → verify by `just check-syntax`, and the step 5 build still passing
   (the skill body is copied into the Codex rules).
   Traps: `agent-rules.nix` strips the SKILL.md frontmatter by splitting on
   `\n---\n`. Do not add a line containing only `---` to the body.

7. Build the hosts: `just test-host p620` and `just test-host razer`.
   → verify by both builds succeeding.
   Traps: p510 is built only if you ask. Run both builds on p620:
   `test-host razer` only builds, so it does not need the razer machine.

8. Commit steps 1–6 on `feat/2079-sonnet-coder-handoff`, push, and open the
   PR. The PR links the intent, spec and plan, and says Opus implemented
   every step.
   → verify by CI (`NixOS Configuration CI`) passing on the PR.
   Traps: write the commit message and PR body with `-F -` or
   `--body-file`. Backticks in `git commit -m` run as commands, and the bus
   guard matches words like "deploy" in command text.

9. After merge, deploy p620 only (`just quick-deploy p620`). Announce it on
   `#agents` first, as rule 6 requires.
   → verify by the checks in Tests below.
   Traps: before deploying, check that no `nhs` or `nh os` is running
   (`pgrep -af 'update-commit-deploy|nh os'`). razer comes after p620
   passes, and p510 only with your approval.

## Tests

- **Build.** `just check-syntax` passes, and `just test-host p620` and
  `just test-host razer` both build.
- **Codex rules.** On the step 5 build output, `grep -c coder` prints `0`.
  After the p620 home-manager switch, `grep -c "Model split" ~/.codex/AGENTS.md ~/.gemini/AGENTS.md`
  prints `0` for both files.
- **Agent file.** `ls -l /etc/claude-code/.claude/agents/coder.md`, and
  `grep command: /etc/claude-code/.claude/agents/coder.md` shows a store
  path.
- **Agent loads.** A new `claude` session on p620, asked for its available
  agent types, lists `coder` with its description. If it is missing, use
  the fallback. That is a deviation, so update this plan in the same commit
  as the fallback code.
- **Guard.** Start the coder once with a prompt that asks it to run, in
  order, `git commit --allow-empty -m probe`, `nixos-rebuild --help` and
  `just check-syntax`. The first two are blocked with the guard's message.
  The third runs.
- **Model.** The same probe session reports that the agent ran on Sonnet
  (the task notification shows the model).

## Rollback

`git revert` the implementation commit on `main` and deploy p620 again.
This removes `/etc/claude-code/.claude/agents/coder.md` and the managed
CLAUDE.md section, and `agent-rules.nix` goes back to copying the whole
policy. Nothing stateful is created, so nothing else needs cleaning up. If
the fallback seed was used, also delete `~/.claude/agents/coder.md` by hand
on each host, because the activation step only ever creates it.
