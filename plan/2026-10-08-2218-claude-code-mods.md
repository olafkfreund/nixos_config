---
status: approved
issue: 2218
spec: spec/2026-10-08-2218-claude-code-mods.md
---

# Plan: ship the fleet-guard and nix-flavour mods from the repo

## Summary of approved decisions

- **Hosts:** the mods load on p620 and razer only. p510 is untouched.
- **Managed guards:** the managed settings hooks stay exactly as they are and are the only enforcement of the bus
  and p510 rules. Managed `PreToolUse` hooks run before any mod, so no mod can sit in front of them.
- **Package:** one package, `pkgs/claude-code-mods/`, is a plugin marketplace named `freundcloud-mods` that holds
  both plugins. Its `checkPhase` runs `claude plugin validate` and `claude plugin test` on each plugin with
  `HOME=$TMPDIR`, using `claude-code-native`. A Claude Code bump that breaks a mod fails the build.
- **Module:** `modules/programs/claude-code-mods.nix` defines `modules.programs.claude-code-mods.{enable,
  fleetGuard.enable, nixFlavour.enable}`. `enable` defaults to false; the other two default to true. When enabled:
  - `environment.etc."claude-code/plugins".source` is the package.
  - **fleet-guard, managed scope:** add `extraKnownMarketplaces.freundcloud-mods.source = { source = "directory";
    path = "/etc/claude-code/plugins"; }` and `enabledPlugins."fleet-guard@freundcloud-mods" = true` to
    `modules.programs.claude-code-managed.settings`. Do not set `prependPlugins`.
  - **nix-flavour, user scope:** `environment.sessionVariables.CLAUDE_CODE_PLUGIN_DIRS =
    "/etc/claude-code/plugins/nix-flavour"`.
- **fleet-guard is visibility only:**
  - hard denies for backticks or `$(` inside a double-quoted `git commit -m`, and for `home-manager switch`;
  - an `AbovePrompt` band with the latest 3 `#agents` messages, polled every 60 s through
    `read_new(agent: "fleet-guard-<host>")`, merged into a rolling list of 3 in `$.store`, and mirrored to a
    `$.state` atom;
  - `/announce <text>`, which posts `[<host>] <text>`.

  No deploy, p510 or ask logic.
- **nix-flavour** behaves exactly as the prototype. Its parsing moves into a pure `status.ts` with a test. It reads
  `/home/olafkfreund/.config/nixos/nixarchy-theme.nix`.
- **Fallback if the `/etc` symlink doesn't count as "loaded in place":** set the marketplace `path` to the store path
  of the package.

## Source material

The working prototypes are in `/home/olafkfreund/.claude/dev-mods/bafaf603-2df4-4581-bf0b-b981440800e6/`, under
`fleet-guard/` and `nix-flavour/`. Read them first.

The mod API's types for this Claude Code build are in
`/tmp/claude-1000/bundled-skills/2.1.291/f23baa917f13ffe070cc35840bd540a0/plugin-authoring/types/claude-code.d.ts`.
Grep it; don't guess signatures. Example mods are in `../examples/` next to it:

- `band.tsx` and `band-state.d.ts` show an `AbovePrompt` band with atoms and a Hide button;
- `pane.tsx` shows command registration.

These facts are verified:

- `command.run` input has `command` and `args` (a string).
- `$.store.get(key)` and `$.store.set(key, value)`.
- `$.mcp.call(server, tool, args)` returns `{ content: [{ type: "text", text }] }`.
- The bus returns JSON text. `search` gives `{ count, hits: [{ from, at, text, event_id, thread }] }`, with `at` in
  milliseconds since the epoch. Parse `read_new` tolerantly: take the first array found at the top level of the
  parsed JSON (`messages`, `hits`, `events` or similar) whose items have `text`. If parsing fails, show nothing.

## Steps

1. Create `pkgs/claude-code-mods/.claude-plugin/marketplace.json`:

   ```json
   { "name": "freundcloud-mods", "owner": { "name": "olafkfreund" },
     "plugins": [
       { "name": "fleet-guard", "source": "./fleet-guard", "description": "Agent-bus band, /announce, commit and home-manager guards" },
       { "name": "nix-flavour", "source": "./nix-flavour", "description": "NixOS spinner words; host, generation, reboot and theme status line" } ] }
   ```

   → verify with `jq empty` on the file.
   Traps: none.

2. Create `pkgs/claude-code-mods/nix-flavour/`:
   - Copy the prototype's `.claude-plugin/plugin.json`, adding `"author": { "name": "olafkfreund" }`.
   - Copy `hooks/hooks.json`.
   - In `hooks/register.ts`, move the parsing into a new `hooks/status.ts` that exports
     `formatStatus(readlinkStdout: string, themeFile: string): string`. That function holds today's host,
     generation, kernel and theme logic and returns the same text. `refresh` keeps doing the I/O and calls it.
   - Add `hooks/status.test.ts`, which imports `test` and `expect` from `claude-code/testing`. It covers:
     - a normal p620 readlink output with matching kernels, which has no reboot marker;
     - mismatched kernels, which shows `⟳ new kernel, reboot`;
     - a missing theme file (an empty string), which has no theme segment.

   → verify with `claude plugin validate pkgs/claude-code-mods/nix-flavour`, which reports no errors, and
   `claude plugin test pkgs/claude-code-mods/nix-flavour`, where everything passes.
   Traps: a module may not use `import()`. `$` may only be passed to functions declared at the top level of the
   file (the validator refuses anything else). Write files with Write/Edit, not shell heredocs: the
   bus-announce guard matches words like "reboot" in command text.

3. Create `pkgs/claude-code-mods/fleet-guard/`:
   - `.claude-plugin/plugin.json`: name, version `0.2.0`, description, author, `"types": "./types/index.d.ts"`.
   - `hooks/hooks.json`: `{ "modules": ["./register.tsx"] }`.
   - `hooks/classify.ts`: keep only the commit-backtick and `home-manager switch` denies. Delete `DEPLOY`,
     `DISRUPTIVE`, `P510` and the `ask` verdict, so the type is `{ kind: 'pass' } | { kind: 'deny'; reason }`.
   - `hooks/bus.ts`: pure helpers, each with a test:
     - `parseBus(text: string): { at: number; text: string }[]` (tolerant, as described under Source material);
     - `mergeRecent(old, fresh, n = 3)`, which dedupes on `at` and `text`, sorts by `at` and keeps the last `n`;
     - `bandLine(m, columns)`, which gives `HH:MM <first line of text>` cut to `columns`.
   - `types/index.d.ts`: `export type BusLine = { at: number; text: string }`, plus
     `declare module 'claude-code' { interface PluginState { 'fleet-guard': { recent: BusLine[]; isHidden: boolean } } }`.
   - `hooks/register.tsx`:
     - `session.start`:
       - Read the host from `readlink /run/current-system`.
       - Register the `announce` command (description `Post to #agents as this host`, argument hint `<text>`).
       - Run `poll($, host)` once, then `$.clock.every(60_000, ...)`.
     - `poll`, a top-level function:
       1. Call `$.mcp.call("agent-bus", "read_new", { agent: "fleet-guard-" + host, limit: 20 })` and `parseBus`
          the result.
       2. Merge it with `$.store.get("recent")`, then `$.store.set` the merged list.
       3. `update` the `recent` atom.
       4. Wrap the whole thing in try/catch and leave the list unchanged on error.
     - `command.run` for `announce`:
       - With empty args, return `{ text: "Usage: /announce <text>" }`.
       - Otherwise post `{ text: "[" + host + "] " + args }` through `$.mcp.call("agent-bus", "post", ...)`,
         return `{ text: "Posted to #agents: " + args }`, then poll.
     - `ui.render` for `AbovePrompt`:
       - Return `next(e)` when `e.props.hasSurvey` is set, the list is empty or `isHidden` is true.
       - Otherwise draw a `Box` of dim `Text` lines, each `bandLine(m, e.props.bodyColumns)`, plus a **Hide**
         button that sets `isHidden`.
     - `tool.call` for `Bash`: a `deny` from `classify` returns `{ deny: "fleet-guard: " + reason }`; otherwise
       `next(e)`. Add `.catch(($, e, next) => next(e))`.
   - Tests:
     - `hooks/classify.test.ts`: the deny cases and passes from the prototype, minus the deploy rows. Add that
       `just p620` and `nix-collect-garbage` now pass, because the managed guards own them.
     - `hooks/bus.test.ts`: `parseBus` on the sample `search` payload above and on garbage (which gives `[]`),
       the dedupe and order of `mergeRecent`, and the truncation in `bandLine`.

   → verify with `claude plugin validate pkgs/claude-code-mods/fleet-guard`, which reports no errors, and
   `claude plugin test pkgs/claude-code-mods/fleet-guard`, where everything passes.
   Traps: as in step 2. JSX compiles against the global `h`. Take elements from
   `const { Box, Text, Button } = $.ui.resolve(e)`. A render hook never writes state; write from `onPress` or from
   another event.

4. Create `pkgs/claude-code-mods/default.nix`:

   ```nix
   { stdenvNoCC, claude-code-native }:
   stdenvNoCC.mkDerivation {
     pname = "claude-code-mods";
     version = "0.2.0";
     src = ./.;
     dontBuild = true;
     doCheck = true;
     checkPhase = ''
       runHook preCheck
       export HOME=$TMPDIR
       for p in fleet-guard nix-flavour; do
         ${claude-code-native}/bin/claude plugin validate ./$p
         ${claude-code-native}/bin/claude plugin test ./$p
       done
       runHook postCheck
     '';
     installPhase = ''
       mkdir -p $out
       cp -r ${./.}/. $out/
       rm -f $out/default.nix
     '';
   }
   ```

   The install copies from the pristine source, so anything the checks write (`.claude-plugin/types/`) stays out of
   `$out`. Add `claude-code-mods = pkgs.callPackage ./claude-code-mods { };` to `pkgs/default.nix`, after
   `claude-code-native`, and `claude-code-mods = final.callPackage ../pkgs/claude-code-mods { };` to
   `overlays/custom-packages.nix`, after `claude-code-native`.
   → verify with `nix build --no-link -L .#nixosConfigurations.p620.pkgs.customPkgs.claude-code-mods`, or the
   attribute path that resolves. The check output must show both plugins validated and tested.
   Traps:
   - Make sure `claude plugin validate` exits non-zero on errors. If it only prints them, grep the output for
     `✘` and `exit 1`.
   - If the sandbox breaks the CLI for environmental reasons (no network, no `/etc/passwd`), stop and report
     rather than turning the checks off. Offline with an empty HOME was confirmed to work outside the sandbox.

5. Create `modules/programs/claude-code-mods.nix` in the repo's module shape (`with lib; let cfg = ...; in`). It
   holds the options above and `config = mkIf cfg.enable (mkMerge [ ... ])`, with these entries:
   - always: `environment.etc."claude-code/plugins".source = pkgs.customPkgs.claude-code-mods;`
   - under `mkIf cfg.fleetGuard.enable`: the `extraKnownMarketplaces` and `enabledPlugins` entries in
     `modules.programs.claude-code-managed.settings`
   - under `mkIf cfg.nixFlavour.enable`:
     `environment.sessionVariables.CLAUDE_CODE_PLUGIN_DIRS = "/etc/claude-code/plugins/nix-flavour";`

   Add an assertion that fleet-guard requires `config.modules.programs.claude-code-managed.enable`. Import the file
   in `modules/programs/default.nix`, after `./claude-code-managed.nix`, with a trailing comment naming Issue
   #2218.
   → verify with `nix-instantiate --parse` on both files.
   Traps:
   - Explicit imports only.
   - No `mkIf cond true`.
   - Use the same `pkgs.customPkgs` path that other modules use for `claude-code-native`; grep for it.

6. Enable it in `hosts/p620/configuration.nix` and `hosts/razer/configuration.nix`, directly after each host's
   `modules.programs.claude-code-managed = { ... };` block:

   ```nix
   modules.programs.claude-code-mods.enable = true; # fleet-guard + nix-flavour (#2218)
   ```

   → verify with `grep -n claude-code-mods hosts/*/configuration.nix`, which shows p620 and razer only.
   Traps: never touch `hosts/p510`.

   **Step 6a, added after the Opus review (recorded in the same commit as the code):**
   - Add a `recent(room, limit=3)` tool to `pkgs/agent-bus-mcp/agent_bus_mcp.py`. It does `/messages` with
     `dir=b`, no cursor and the session identity, and returns the messages oldest first. Add a self-check in
     `test_agent_bus_mcp.py` that asserts the direction, the order and that both cursors stay untouched.
   - In fleet-guard, poll `recent` instead of `read_new`, and drop `$.store` and `mergeRecent`.
   - Poll only when `e.isInteractive`, without awaiting.
   - `/announce` refuses origins other than `composer` and `bridge`, and reports a post with `isError`.
   - `parseBus` drops bad items one at a time.
   - The commit deny also covers `-am`, `--message` and `git -C`, and passes a quoted `$(cat <<'EOF')` heredoc.
     The `home-manager switch` deny matches only in command position.
   - The header of `claude-code-managed.nix` notes the organization-mod exception.

   → verify with the agent-bus self-check, and with `validate`, `test` and `tsc` on both mods.
   Traps: as in step 3.

7. The session commits steps 1-6 as one commit, `feat(claude-code): ship fleet-guard and nix-flavour mods (#2218)`,
   with the message passed through `-F <file>`.
   → verify that the pre-commit hooks pass.

## Tests

The session runs these after step 7:

1. `nix build` of the package: the check passes for both plugins.
2. `just test-host p620` and `just test-host razer` build.
3. p510 gets no mods. Since step 6a, its closure changes only through `agent-bus-mcp`, which gains the read-only
   `recent` tool, and the bus-peek hook script that references it. `nix-diff` of the p510 toplevel against
   `origin/main` names only those, and the p510 managed-settings diff is that one script path.
4. The managed settings differ only by the two new keys. Run `jq -S` over
   `<p620 toplevel>/etc/claude-code/managed-settings.json` on main and on the branch, then `diff` the two. Only
   `extraKnownMarketplaces` and `enabledPlugins` may appear.
5. Run `just check-syntax` and `nix flake check --no-build`.
6. An Opus agent reviews `git diff origin/main..HEAD` against this plan.
7. Push, then open a PR that links all three artifacts and closes Issue #2218.
8. After the merge and the normal deploy, the user's call (p620 locally, razer through `just deploy-via-p620 razer`),
   start a new login and a new Claude Code session on each host:
   - `/plugin` lists `fleet-guard` and `nix-flavour`.
   - `claude --debug` shows fleet-guard loaded in a tier other than `user`. If it shows `user`, apply the
     store-path fallback.
   - The band shows recent `#agents` lines.
   - `/announce test from <host>` posts.
   - A backticked `git commit -m` is denied.
   - The status line shows the host, generation and theme.

   Then delete the session prototypes in `~/.claude/dev-mods/bafaf603-2df4-4581-bf0b-b981440800e6/`.

## Rollback

Set `modules.programs.claude-code-mods.enable = false` on the host, or `git revert` the commit, then deploy. The
managed guards were never changed, so rolling back removes only visibility. A broken mod can also be switched off
for one session with `claude --safe-mode`.
