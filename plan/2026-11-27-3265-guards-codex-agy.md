---
status: approved
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
     `subagentMetadata` part, add a new group limited to the shell tool
     (when at least one guard is enabled), then one `lib.optionalString`
     per guard (same condition) for its entry:

     ```toml

     [[hooks.PreToolUse]]
     matcher = "^Bash$"

     [[hooks.PreToolUse.hooks]]
     type = "command"
     command = "/etc/codex/hooks/bus-announce"
     timeout = 10
     ```

     (and `shared-checkout`, `p510-deploy` entries in the same group). A
     captured Codex 0.172.0 payload (2026-11-27, `codex exec` with a hook
     dumping stdin) shows the shell tool as `tool_name: "Bash"`, the command
     as a string at `tool_input.command`, and `cwd` set to the command's own
     working directory, not the session's: the same shape the guards
     already read, so the shared-checkout guard sees the right directory.
   → verify: `nix build --no-link --print-out-paths '.#nixosConfigurations.p620.config.environment.etc."codex/requirements.toml".source'`
   and check the file parses (`python3 -c 'import tomllib,sys;tomllib.load(open(sys.argv[1],"rb"))' <file>`)
   and lists four PreToolUse commands.
   Traps: the lead commits each step before its verify.

2. agy adapter (codex).
   - New `modules/programs/agy-host-guard-adapter.sh` (shellcheck-clean
     bash, `@jq@` and `@guards@` placeholders like `agy-guard-adapter.sh`):
     read the payload; `allow` prints `{"decision":"allow"}` and exits 0.
     Unreadable payloads and tools other than `run_command` are allowed.
     agy decodes args with Go's case-insensitive JSON (see
     `agy-guard-adapter.sh`), so for `run_command`:
     - any non-ASCII key in `.toolCall.args` → deny ("refuses non-ASCII key
       names");
     - the command is the value of the args keys whose `ascii_downcase` is
       `commandline`; zero such keys, or a non-string value → allow (nothing
       to run); more than one such key → deny ("ambiguous CommandLine");
     - the directory `$d` is the single args key whose `ascii_downcase` is
       `cwd`, if it is a non-empty string naming an existing directory;
       otherwise the first `.workspacePaths[]` string that is an existing
       directory; otherwise omit `cwd`.
     Build `{tool_input:{command:$c}}` plus `cwd:$d` when set, and for each path in
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
     with a non-string CommandLine → allow; `commandline` in lower case →
     still checked (deny for `danger`); two command keys differing in case →
     deny; a non-ASCII key → deny; `Cwd` empty, non-string or missing → the
     stub sees `workspacePaths[0]` (use a stub that echoes its `.cwd` to a
     file); non-JSON input → allow and
     valid JSON output; output is always one JSON object. Exit 1 on any
     mismatch, print `ALL PASSED` otherwise.
   - `modules/programs/claude-code-managed.nix`, in the `let`:

     ```nix
     hostGuards = lib.optional cfg.busAnnounceGuard.enable "${busAnnounceScript}"
       ++ lib.optional cfg.sharedCheckoutGuard.enable "${sharedCheckoutGuardScript}"
       ++ lib.optional cfg.deployGuard.enable "${deployGuardScript}";
     agyHostGuardScript = pkgs.writeShellScript "agy-host-guard"
       (builtins.replaceStrings [ "@jq@" "@guards@" ]
         [ "${pkgs.jq}/bin/jq" (lib.concatStringsSep " " hostGuards) ]
         (builtins.readFile ./agy-host-guard-adapter.sh));
     ```

     and `environment.etc."antigravity/hooks/host-guard".source = agyHostGuardScript;`
     next to the coder-guard one (~line 1229).
   → verify: `bash modules/programs/agy-host-guard-adapter.test.sh` prints
   `ALL PASSED`; `shellcheck -s bash` on the adapter; p620 builds.

3. hooks.json, `home/development/antigravity-config.nix`.
   - `coderGuardHookEntry` (~line 132): add a second top-level key
     `"host-guard"`, shaped like `coder-guard` (escape the command exactly
     as the coder-guard one is escaped):

     ```nix
     "host-guard" = {
       PreToolUse = [{
         matcher = "run_command";
         hooks = [{
           type = "command";
           command = "/bin/sh -c '[ -x /etc/antigravity/hooks/host-guard ] || { echo \"{\\\"decision\\\":\\\"allow\\\"}\"; exit 0; }; exec /etc/antigravity/hooks/host-guard'";
           timeout = 10;
         }];
       }];
     };
     ```

     Rename the binding only if nothing else reads it; `agy-implement`'s
     check compares the `coder-guard` key alone, so it keeps working.
   - `antigravityCoderGuardHook` activation (lines 407-433): when hooks.json
     is a JSON object, replace the key-exists test with a value comparison,
     as `agent-voice.nix` does:

     ```bash
     jq -e --slurpfile want "$entry" \
       '(."coder-guard" == $want[0]."coder-guard") and (."host-guard" == $want[0]."host-guard")' \
       "$hooksfile"
     ```

     Equal → leave the file alone (formatting differences never cause a
     write). Different → `jq -s '.[0] + .[1]' "$hooksfile" "$entry"` into a
     temp file, then `$DRY_RUN_CMD mv` it into place. Print one line saying
     which happened. Keep the missing-file and not-an-object branches.
   → verify: run the built activation snippet against temp copies of
   hooks.json: (a) missing `host-guard` → added; (b) stale `coder-guard`
   value → replaced; (c) equal values in compact formatting → file
   untouched (same bytes and mtime); `agent-say` and `nixi-working` keys
   preserved in all cases. Then run the whole home activation once on p620
   after the switch and check all four keys are present.

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
- After the switch, on p620:
  - `/etc/codex/requirements.toml` lists `bus-announce`, `shared-checkout`,
    `p510-deploy` under a `^Bash$` group; `jq 'keys' ~/.gemini/config/hooks.json`
    includes `host-guard`.
  - Adapter by hand: a `run_command` payload for `just gc` → deny with the
    bus message; `echo hi` → allow.
  - Live, with an inert command that the bus guard matches and that does
    nothing if it ever ran (`systemctl --user stop zz-3265-nonexistent.service`):
    a headless `agy -p` and a `codex exec`, each asked to run exactly that
    command in a scratch directory, both report it was blocked by the
    managed-settings bus guard; the same asked to run `echo ok` succeeds.
  - Same file checks on razer.
- Not verified, recorded on the PR: how Codex treats a hook that crashes or
  times out (the guards fail closed on their own errors; a Codex-side
  timeout is outside them).

## Rollback

Revert the PR and switch again. The old activation leaves hooks.json alone
when `coder-guard` exists, so the `host-guard` key stays; its command allows
once `/etc/antigravity/hooks/host-guard` is gone, so it is harmless.
