---
status: approved
issue: 1861
spec: spec/2026-09-16-1861-global-codex-instructions.md
---

# Plan: global Claude standards for every Codex session

Work on `feat/1861-global-codex-instructions`. Implement only after this plan
is approved. Preserve the approved spec and intent in their current locations.

## Approved decisions

- Extend `home/development/agent-rules.nix`, which already installs global
  Codex instructions at `~/.codex/AGENTS.md`. Use the existing Home Manager
  integration; no launcher, synchronization service, or Codex config changes.
- Add `home/development/agent-rules/codex-standards.md` as a maintained copy
  of the user's global `/home/olafkfreund/.claude/CLAUDE.md`, not the repository
  `CLAUDE.md`. Record provenance and copy date. Future updates are explicit
  edits to this tracked copy followed by a rebuild, not automatic synchronization.
- Change its title and purpose to Codex. Preserve the detailed PLAN, ACT,
  REFLECT, REVISE protocol, mandatory behaviours, quality gates, output examples,
  and example cycle. Preserve the approved-plan exception and the requirement
  to update `plan/` with implementation deviations in the same commit.
- Preserve the on-demand Agent OS references to
  `~/.agent-os/standards/{tech-stack,code-style,best-practices}.md` and the
  caveat that project standards override the Rails/PostgreSQL/React defaults.
  Instruct Codex to report missing referenced files rather than invent contents.
- Label `/plan-product`, `/create-spec`, `/execute-tasks`, and `/analyze-product`
  as Claude commands. Codex follows the included artifact workflow and available
  task-relevant skills. Replace the Claude-only `nixos-standards` reference
  with the installed `nixos` and applicable specialized NixOS skills.
- Generate Codex content in order: existing `agent-rules/global.md`, new
  `codex-standards.md`, existing adapted managed workflow policy, then existing
  artifact templates with skill frontmatter stripped. Replace the short PARR
  inclusion with the detailed protocol rather than including both.
- Share the existing common content between outputs with a minimal refactor.
  Preserve policy and frontmatter assertions for both outputs. Correct the stale
  comment claiming Codex cannot load skills: inlining makes policy independent
  of whether a skill is selected.
- Keep Antigravity's generated content byte-identical, including its short PARR
  protocol. Do not change Claude's global file or Syncthing ownership.
- Build and activate p620 only. Other importing hosts receive the change at
  their normal deployment. Do not build or deploy p510. Custom Codex homes and
  cloud/remote environments need their own installation; this task covers the
  managed default local home. Restart existing sessions for the new instructions.
- Verify from outside the repository that a fresh Codex session sees the rules.
  Check the generated size against the installed Codex document limit and ensure
  no global override file masks the managed file.

## Steps

1. **Capture the baseline before editing.** Check the branch and worktree; read
   the current global Claude source and `agent-rules.nix`. Save the installed
   Claude file checksum and build the current p620 Antigravity instructions
   into a temporary baseline. Check the current Codex home, override file, and
   configured/default document limit without printing unrelated configuration.
   → Verify the baseline is readable, the source has not unexpectedly changed,
   and the active Codex home is the intended one. Stop to assess any discrepancy.

2. **`home/development/agent-rules/codex-standards.md`:** copy the global Claude
   source and apply only the adaptations listed above. Add the implementation
   deviation rule from the current short PARR text.
   → Review the diff against the original: all detailed protocol sections and
   standards references remain; adaptations and provenance explain differences.

3. **`home/development/agent-rules.nix`:** reuse the common global rules and
   workflow fragments to generate separate Codex and Antigravity documents.
   Codex uses the detailed standards; Antigravity retains the original sequence.
   Preserve both content assertions and correct the stale skills comment.
   Stage the new Markdown source so flake evaluation includes it.
   → Build both p620 home-file sources; run the content checks below and compare
   Antigravity against the baseline with `cmp`. Require identical bytes.

4. **Validate and commit.** Run the syntax, flake, and p620 build commands below
   separately, checking each result. Inspect the diff and commit only the two
   implementation files plus any necessary plan deviation as
   `feat(agents): include global Claude standards in Codex (#1861)`.
   → Checks and commit hooks pass; the worktree is clean and the diff is scoped.
   Do not fix unrelated validation failures silently or declare failed checks passed.

5. **Activate on p620.** Show the reviewed diff, record the current system
   generation, and read `#agents:freundcloud.org.uk` for ongoing jobs. Announce
   the activation and estimated duration through the agent-bus skill's tools.
   Wait if another job conflicts. Run `AGENT_BUS_ANNOUNCED=1 just p620` only after
   the announcement and successful validation.
   → Activation succeeds and the installed Codex document matches the built
   output. Compare Claude's checksum and Antigravity's bytes with their baselines.
   Do not bypass a missing bus connection or failed activation check.

6. **Check global loading.** Start the read-only ephemeral Codex command below
   from outside this repository, using the normal local subscription login.
   Do not put the expected answers into its prompt or change the selected model.
   → It identifies the Agent OS paths and intent/spec/plan approvals from the
   global instructions. If unavailable or incorrect, diagnose and report the
   verification gap; do not infer success from the installed file alone.

7. **Publish for review.** Push the task branch and open a PR with `Closes #1861`,
   links to all three artifacts, the final behavior, and verification results.
   → Report the PR and p620 activation outcome; remind the user to start fresh
   sessions and note that other hosts await their normal deployment. Do not merge.

## Tests

Run commands individually and inspect each result before proceeding.

- Build each document using `nix build --no-link --print-out-paths` with:
  - `'.#nixosConfigurations.p620.config.home-manager.users.olafkfreund.home.file.".codex/AGENTS.md".source'`
  - `'.#nixosConfigurations.p620.config.home-manager.users.olafkfreund.home.file.".gemini/AGENTS.md".source'`
- Use `cmp` to require byte equality between the baseline and new Antigravity
  output, and between built and installed Codex output after activation.
- Check the Codex output contains the detailed `Expert Reasoning Protocol`,
  `Quality Gates`, Agent OS paths, existing NixOS rules, artifact approval gates,
  and `Intent template`, `Spec template`, and `Plan template` sections.
  It must not contain the short `MANDATORY: Follow PARR Protocol for This Task`
  block, skill YAML `name: artifact-workflow`, or stale policy `Load it` wording.
  Check required sections occur as intended without duplicate PARR protocols.
- Check generated byte size against the installed Codex document limit. The
  current config has no explicit `project_doc_max_bytes`; verify the default
  through installed documentation or official documentation during implementation.
- `just check-syntax`: inspect output for syntax failures, not just exit status,
  because its recipe does not return failure when it finds a parse error.
- `just validate`: all required checks pass. Recipe inspection confirmed it runs
  `nix flake check`; `checks/default.nix` contains source checks, not p510 builds.
- `just test-host p620`: the p620 system closure builds successfully.
- Fresh-session loading check:

  ```bash
  codex exec --sandbox read-only --ephemeral --skip-git-repo-check -C /tmp \
    'Without using tools or reading files, identify the Agent OS standards paths and the approval stages required before a multi-file implementation, from your loaded global instructions.'
  ```

  Expected: the three `~/.agent-os/standards/` Markdown files and approved
  intent, spec, and plan stages. No filesystem lookup to obtain the answer.

## Rollback

- Before activation: revert the implementation commit; no running configuration
  has changed. Preserve the artifact approval history.
- After activation: revert the implementation commit, validate and build p620,
  announce on the agent bus, then run `AGENT_BUS_ANNOUNCED=1 just p620`.
- For an activation regression requiring immediate recovery: announce first,
  then `AGENT_BUS_ANNOUNCED=1 sudo nixos-rebuild switch --rollback` on p620.
- Verify the previous global instructions are restored and start fresh Codex
  sessions. Claude and Antigravity should have required no content changes.
