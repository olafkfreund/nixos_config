---
status: approved
issue: 2218
intent: intent/2026-10-08-2218-claude-code-mods.md
---

# Spec: ship the fleet-guard and nix-flavour mods from the repo

## Design

### One package that is a marketplace: `pkgs/claude-code-mods/`

The mods' source lives in the repo as a plugin marketplace directory:

```text
pkgs/claude-code-mods/
├── default.nix                     builds $out = this tree, checks it
├── .claude-plugin/marketplace.json name "freundcloud-mods", both plugins by relative path
├── fleet-guard/                    plugin.json, hooks/{hooks.json,register.tsx,classify.ts,*.test.ts}, types/
└── nix-flavour/                    plugin.json, hooks/{hooks.json,register.ts,status.ts,status.test.ts}
```

`default.nix` is a `stdenvNoCC.mkDerivation` that copies the tree to `$out`. Its `checkPhase` runs
`claude plugin validate` and `claude plugin test` on each plugin with `HOME=$TMPDIR`, using
`claude-code-native` from this repo. Both commands were confirmed to pass offline with an empty HOME. Because
`claude-code-native` is an input, a Claude Code bump rebuilds the mods and fails the build if the early-access
API moved under them. That meets the intent's constraint that a bump must not leave a broken mod unnoticed. The
package is wired like its neighbours: `pkgs/default.nix` and `overlays/custom-packages.nix`.

### One NixOS module: `modules/programs/claude-code-mods.nix`

The options sit beside `modules.programs.claude-code-managed`:

- `modules.programs.claude-code-mods.enable` (default false)
- `.fleetGuard.enable` and `.nixFlavour.enable` (both default true once the module is enabled)

When enabled:

- `environment.etc."claude-code/plugins".source = <the package>`. The marketplace is then at the fixed path
  `/etc/claude-code/plugins`, which only root can write and which the store backs.
- **fleet-guard, managed scope.** The module adds to `modules.programs.claude-code-managed.settings`, whose type
  is `attrsOf anything`, so the keys merge:

  ```nix
  extraKnownMarketplaces.freundcloud-mods.source = { source = "directory"; path = "/etc/claude-code/plugins"; };
  enabledPlugins."fleet-guard@freundcloud-mods" = true;
  ```

  This meets the documented conditions for an organization's mod: a managed `enabledPlugins` entry, a directory
  marketplace given by an absolute path, and a plugin listed by relative path and loaded in place. It therefore
  runs ahead of user mods, and the user can't disable it by accident. `prependPlugins` is not set: an
  organization's mod already runs before user mods, and setting the list would mean restating
  `sec-default@builtin`.
- **nix-flavour, user scope.** `environment.sessionVariables.CLAUDE_CODE_PLUGIN_DIRS =
  "/etc/claude-code/plugins/nix-flavour"`. It loads as a `--plugin-dir` plugin in the user tier, per host, and
  touches nothing in `~/.claude`.

The module is imported in `modules/programs/default.nix` beside `claude-code-managed.nix`. It is enabled in
`hosts/p620/configuration.nix` and `hosts/razer/configuration.nix`, next to their `claude-code-managed` blocks.
p510 stays untouched.

### fleet-guard, revised to visibility (the intent's decision)

- **Hard denies.** `classify.ts` shrinks to these two patterns:
  - backticks or `$(` inside a double-quoted `git commit -m`
  - `home-manager switch`

  The deploy, p510 and ask logic is deleted, because the managed guards own it and run first. The
  `tool.call` hook on `Bash` denies a match and passes everything else on.
- **The band.** An `AbovePrompt` band shows the latest 3 `#agents` messages, one dim line each, cut to the band's
  width. It is hidden when there's nothing to show, and a **Hide** button hides it for the session. Data:
  - In interactive sessions, `session.start` starts a poll without waiting on it, then `$.clock.every(60 s)`
    keeps polling. Headless sessions don't poll.
  - Each poll calls the bus's `recent` tool (`limit: 3`). The tool was added to `pkgs/agent-bus-mcp` for this:
    it reads the newest messages backwards (`dir=b`) with no cursor, under the session's own identity. So
    polling registers no accounts and moves no read position.
  - The result goes into a `$.state` atom, so the band redraws.
  - If the bus is unreachable, nothing is drawn.
  - Revised after review on 2026-10-08 (the user's decision). The first design used
    `read_new(agent: "fleet-guard-<host>")`, but the bus names an `agent` per session and registers a Matrix
    account for each one. Its first read also starts from the room's oldest message.
- **`/announce <text>`.** Registered in `session.start`, it posts `[<host>] <text>` to `#agents` through
  `$.mcp.call("agent-bus", "post", ...)` and answers with a one-line confirmation, or with the error when the
  post fails. It runs only when a person typed it: a `composer` or `bridge` origin. It runs instantly, with no
  Claude turn. With no text, it answers with usage.
- **The host** is read once from the `/run/current-system` link name, as nix-flavour already does.

### nix-flavour: unchanged in behaviour

The readlink and theme parsing move into a pure `status.ts`, so a test can cover them. It keeps reading
`/home/olafkfreund/.config/nixos/nixarchy-theme.nix`, the file that manages the theme (the intent's decision).
That shows the theme the next rebuild will apply, which can run ahead of GTK and the console until the rebuild.

## Alternatives rejected

- **Enable nix-flavour in `~/.claude/settings.json` `enabledPlugins`.** That file is synced to p510 by Syncthing,
  so the entry would reach p510, which has no marketplace, and could not be kept per host.
- **`claude plugin marketplace add` / `install`.** Imperative state in `~/.claude/plugins`, not declarative.
- **The store path in `CLAUDE_CODE_PLUGIN_DIRS`.** Session variables refresh only at login, so after a rebuild and
  a garbage collection a running login would point at a deleted path. `/etc/claude-code/plugins` never moves.
- **Move the bus and p510 checks into fleet-guard.** Rejected by the user. The managed shell hooks stay the
  enforcement, because a mod is unloaded by `--safe-mode` or by three worker crashes.
- **The hard denies as managed shell hooks.** They would also cover `claude -p`. They are kept in the mod because
  they're already tested there and the mistakes they catch happen in interactive sessions. Moving them later is a
  small change if headless sessions turn out to need them.

## Risks

- **The `/etc` symlink may not count as "loaded in place".** The marketplace path is a store-backed symlink. If
  the debug log shows `fleet-guard` in `tier user` rather than ahead of user mods, the fallback is to point
  `extraKnownMarketplaces` at the store path directly. That path is absolute and root-only too, and
  managed-settings is regenerated with it on every rebuild.
- **Early-access API churn.** This is caught at build time by the `checkPhase`. A bump that breaks a mod fails
  `nix build`, not the sessions.
- **Mods fail open.** If the hooks worker crashes or `--safe-mode` is used, both mods are off. Nothing depends on
  them for safety any more, so that is acceptable by design.
- **First load needs a new login.** `CLAUDE_CODE_PLUGIN_DIRS` reaches new logins only. fleet-guard needs only a
  new Claude Code session.
- **Duplicate prototypes.** This session's `~/.claude/dev-mods/<session-id>/` copies would load next to the
  installed ones in this session only. They are deleted after the deploy.

## Verification

1. `nix build .#claude-code-mods`: the `checkPhase` passes `validate` and `test` for both plugins.
2. `just test-host p620` and `just test-host razer` build.
3. p510's toplevel `drvPath` is identical to `main`'s, which proves p510 is untouched.
4. The diff of p620's `/etc/claude-code/managed-settings.json`, before and after, adds only
   `extraKnownMarketplaces` and `enabledPlugins`. `hooks` and `permissions` are byte-identical.
5. After the normal deploy (p620 locally, razer via p620), in a new login and a new session on each host:
   - `/plugin` shows `fleet-guard` and `nix-flavour` active.
   - `claude --debug` shows `fleet-guard@freundcloud-mods` loaded in a tier other than `user`.
   - The band lists recent `#agents` messages.
   - `/announce test from <host>` posts.
   - A `git commit -m` with a backtick is denied.
   - The status line shows the host, generation and theme.
