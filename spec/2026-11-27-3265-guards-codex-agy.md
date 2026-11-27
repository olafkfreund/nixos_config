---
status: draft
issue: 3265
intent: intent/2026-11-27-3265-guards-codex-agy.md
---

# Spec: Bus, p510 and checkout guards for Codex and agy

## Design

The three guard scripts in `modules/programs/claude-code-managed.nix`
(`busAnnounceScript`, `sharedCheckoutGuardScript`, `deployGuardScript`)
already read `.tool_input.command` (and `.cwd`) from stdin and exit 0 or 2,
which is Codex's hook contract too.

- **Codex:** install each under `/etc/codex/hooks/` (`bus-announce`,
  `shared-checkout`, `p510-deploy`), each gated on its existing
  `cfg.<guard>.enable`, and register each as another
  `[[hooks.PreToolUse.hooks]]` entry right after `coder-guard` in
  `/etc/codex/requirements.toml` (managed hooks need no trust step).
- **agy:** a new adapter `modules/programs/agy-host-guard-adapter.sh`,
  installed at `/etc/antigravity/hooks/host-guard`. For `run_command` with
  a string `CommandLine`, it builds `{tool_input:{command}, cwd}` (cwd from
  the args' `Cwd`, else the first workspace path) and runs the enabled
  guards in order; exit 2 becomes `{"decision":"deny","reason":<stderr>}`,
  any other non-zero exit becomes a deny naming the failure (Claude Code
  blocks on a failed guard too), otherwise allow. Every other tool, and a
  payload it cannot read, is allowed: this adapter guards host operations,
  not file edits (the coder adapter keeps its fail-closed rules for
  implementers).
- **hooks.json:** a `host-guard` entry (matcher `run_command`, command
  `/bin/sh -c '[ -x /etc/antigravity/hooks/host-guard ] || { echo
  '{"decision":"allow"}'; exit 0; }; exec /etc/antigravity/hooks/host-guard'`,
  quoted as Nix needs) is added to the generated entry file next to
  `coder-guard`. The activation merges the entry file over hooks.json
  (`.[0] + .[1]`) and writes only when the result differs, so both owned
  keys always match Nix; the other modules' keys are untouched.
- **Tests:** `scripts/test-bus-guard.py` and `scripts/test-p510-deploy-guard.py`
  run their cases a second time with a Codex-shaped payload (`tool_input`,
  `cwd`, `hook_event_name`, `tool_name`). New
  `modules/programs/agy-host-guard-adapter.test.sh` with stub guards covers
  deny, allow, guard crash, non-`run_command` and malformed payloads. It
  and the existing `agy-guard-adapter.test.sh` join `just test-guards`.

## Alternatives rejected

- Copying the guard logic per tool: two implementations would drift.
- Fail-closed for all agy tools: plain sessions would lose file edits and
  reads whenever a payload changes shape; the coder adapter already covers
  the implementer case.
- A user hook in `~/.codex/hooks.json`: needs per-hash trust and is skipped
  silently until trusted.

## Risks

- Plain agy and Codex sessions get denials they never had for deploy, GC,
  restart, reboot, branch switching in `~/.config/nixos` and p510 deploys.
  That is the intent; the escape prefixes stay the same.
- Codex's hook payload for its shell tool could carry the command in a
  different field; the coder guard already relies on `.tool_input.command`
  for `codex-implement`.
- A hook that runs on every agy `run_command` adds a little latency.

## Verification

- `just test-guards`, both adapter tests, `just test-host p620`,
  `just test-host razer`.
- After the switch: `/etc/codex/requirements.toml` lists the three hooks;
  `jq 'keys' ~/.gemini/config/hooks.json` includes `host-guard`; a headless
  `agy -p` asked to run a harmless `echo` still works, and one asked to run
  `just gc` is denied with the bus message.
