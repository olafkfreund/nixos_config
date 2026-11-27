---
status: draft
issue: 3265
spec: spec/2026-11-27-3265-guards-codex-agy.md
coders:
  1: coder # three /etc files and three TOML entries, mechanical
  2: codex # small adapter with exit-code and payload edge cases
  3: coder # hooks.json entry and a by-value merge
  4: coder # extra payload cases and test wiring
reviewers:
  - codex # plan review (owner policy: one plan review)
  - agy # diff review by a provider other than the coders'
---

# Plan: Bus, p510 and checkout guards for Codex and agy

Decisions (approved spec): reuse the three existing guard scripts in
`modules/programs/claude-code-managed.nix` unchanged (`busAnnounceScript`,
`sharedCheckoutGuardScript`, `deployGuardScript`: they read
`.tool_input.command` and `.cwd`, exit 0 or 2). Codex gets them as managed
hooks; agy gets them through a new adapter that allows everything except a
guarded `run_command`; the agy hooks.json entries this repo owns are merged
by value; tests cover both payload shapes.

## Steps

1. Codex registration, `modules/programs/claude-code-managed.nix`.
   - Next to `environment.etc."codex/hooks/coder-guard"` (~line 1165) add
     `environment.etc."codex/hooks/bus-announce" = lib.mkIf cfg.busAnnounceGuard.enable { source = busAnnounceScript; };`,
     the same for `shared-checkout` (`cfg.sharedCheckoutGuard.enable`,
     `sharedCheckoutGuardScript`) and `p510-deploy` (`cfg.deployGuard.enable`,
     `deployGuardScript`).
   - In `environment.etc."codex/requirements.toml".text`, right after the
     coder-guard `[[hooks.PreToolUse.hooks]]` block and before the
     `subagentMetadata` part, add one `lib.optionalString` per guard (same
     condition) emitting

     ```toml

     [[hooks.PreToolUse.hooks]]
     type = "command"
     command = "/etc/codex/hooks/bus-announce"
     timeout = 10
     ```

     (and `shared-checkout`, `p510-deploy`). They join the existing
     `[[hooks.PreToolUse]]` group, which has no matcher (every tool; the
     guards exit 0 without a command).
   → verify: `nix build --no-link --print-out-paths '.#nixosConfigurations.p620.config.environment.etc."codex/requirements.toml".source'`
   and check the file parses (`python3 -c 'import tomllib,sys;tomllib.load(open(sys.argv[1],"rb"))' <file>`)
   and lists four PreToolUse commands.
   Traps: the lead commits each step before its verify.

2. agy adapter (codex).
   - New `modules/programs/agy-host-guard-adapter.sh` (shellcheck-clean
     bash, `@jq@` and `@guards@` placeholders like `agy-guard-adapter.sh`):
     read the payload; `allow` prints `{"decision":"allow"}` and exits 0.
     If `.toolCall.name` is not `run_command`, or
     `.toolCall.args.CommandLine` is not a string, allow. Otherwise build
     `{tool_input:{command:$c}, cwd:$d}` with `$d` from
     `.toolCall.args.Cwd // .workspacePaths[0] // ""`, and for each path in
     `@guards@` (space-separated) run it with that input, capturing stderr:
     exit 2 → print `{"decision":"deny","reason":<stderr>}` and exit 0; any
     other non-zero → deny with reason `host guard <name> failed (exit N): <stderr>`;
     all 0 → allow. Always print exactly one JSON object; never exit
     non-zero.
   - New `modules/programs/agy-host-guard-adapter.test.sh` in the style of
     `agy-guard-adapter.test.sh`: substitute `@jq@` with `jq` and `@guards@`
     with stub scripts (one that denies `danger` with exit 2 and a message,
     one that always exits 0, one that exits 1); cases: harmless command →
     allow; `danger` → deny with the stub's message as reason; crashing stub →
     deny naming it; `view_file` and `write_to_file` → allow; `run_command`
     with a non-string CommandLine → allow; non-JSON input → allow and
     valid JSON output; output is always one JSON object. Exit 1 on any
     mismatch, print `ALL PASSED` otherwise.
   - `modules/programs/claude-code-managed.nix`: `agyHostGuardScript =
     pkgs.writeShellScript "agy-host-guard" (builtins.replaceStrings [ "@jq@" "@guards@" ]
     [ "${pkgs.jq}/bin/jq" (lib.concatStringsSep " " (lib.optional cfg.busAnnounceGuard.enable "${busAnnounceScript}" ++ lib.optional cfg.sharedCheckoutGuard.enable "${sharedCheckoutGuardScript}" ++ lib.optional cfg.deployGuard.enable "${deployGuardScript}")) ]
     (builtins.readFile ./agy-host-guard-adapter.sh));` and
     `environment.etc."antigravity/hooks/host-guard".source = agyHostGuardScript;`
     next to the coder-guard one (~line 1227).
   → verify: `bash modules/programs/agy-host-guard-adapter.test.sh` prints
   `ALL PASSED`; `shellcheck -s bash` on the adapter; p620 builds.

3. hooks.json, `home/development/antigravity-config.nix`.
   - `coderGuardHookEntry` (~line 132): add a second top-level key
     `"host-guard"` with `PreToolUse = [ { matcher = "run_command"; hooks = [ { type = "command";
     command = "/bin/sh -c '[ -x /etc/antigravity/hooks/host-guard ] || { echo \"{\\\"decision\\\":\\\"allow\\\"}\"; exit 0; }; exec /etc/antigravity/hooks/host-guard'";
     timeout = 10; } ]; } ];` (escaped exactly like the coder-guard command).
     Rename the binding only if nothing else reads it; `agy-implement`'s
     check compares the `coder-guard` key alone, so it keeps working.
   - `antigravityCoderGuardHook` activation (~lines 406-432): when hooks.json
     is a JSON object, replace the key-exists test with: compute
     `jq -s '.[0] + .[1]' "$hooksfile" "$entry"` into a temp file and move it
     into place (with `$DRY_RUN_CMD`) only if it differs from the current
     file (`cmp -s`); print one line saying which happened. Keep the
     missing-file and not-an-object branches as they are.
   → verify: run the built activation snippet against temp copies of
   hooks.json: (a) missing `host-guard` → added; (b) stale `coder-guard`
   value → replaced; (c) already equal → file untouched (same mtime);
   other keys (`agent-say`, `nixi-working`) preserved in all cases.

4. Tests and wiring.
   - `scripts/test-bus-guard.py` and `scripts/test-p510-deploy-guard.py`:
     run every case a second time with the Codex payload shape
     `{"tool_input": {"command": cmd}, "cwd": "/tmp", "hook_event_name": "PreToolUse", "tool_name": "Bash"}`,
     reporting both; same expected exit codes.
   - `Justfile` `test-guards` (lines 169-177): add
     `@bash ./modules/programs/agy-guard-adapter.test.sh` and
     `@bash ./modules/programs/agy-host-guard-adapter.test.sh`.
   → verify: `just test-guards` passes.

5. Lead only: `just test-host p620`, `just test-host razer`; agy diff
   review; PR; merge; bus announcement; switch p620, then razer via p620;
   post-switch checks.

## Tests

- `just test-guards` (now including both agy adapter tests).
- After the switch, on p620: `/etc/codex/requirements.toml` lists
  `bus-announce`, `shared-checkout`, `p510-deploy`;
  `jq 'keys' ~/.gemini/config/hooks.json` includes `host-guard`;
  feeding the installed adapter a `run_command` payload for `just gc`
  returns a deny with the bus message, and `echo hi` returns allow;
  `agy -p 'run: echo ok' --mode accept-edits` style smoke (headless) still
  completes. Same file checks on razer.

## Rollback

Revert the PR and switch again; the activation then rewrites hooks.json
with only the `coder-guard` key it owns at that version (the stale
`host-guard` key would stay, harmless: its command allows when the /etc file
is gone).
