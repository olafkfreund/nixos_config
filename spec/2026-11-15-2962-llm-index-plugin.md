---
status: draft
issue: 2962
intent: intent/2026-11-15-2962-llm-index-plugin.md
---

# Spec: bump llm-index to the identity fix and install its shell plugin

## Design

Two changes, each its own PR merged to main and then deployed. They follow
the approved upstream designs (nixarchy-llm-index #14 and #15).

### Stage 1: the input bump (PR 1)

- `flake.nix:153`: the `nixarchy-llm-index` URL rev goes from `491f256…` to
  `54e0fbebf8a5ce6ea6ccc3056350eb533a95b0f1`, the merge of #17 on main,
  which also contains #16.
- `flake.lock`: `nix flake lock --update-input nixarchy-llm-index` moves only
  that input.
- Nothing else changes. The service, roots, limits and MCP registration stay
  as they are. Activation re-registers the public server in Claude Code,
  Codex and agy, because the store path changes (`llm-index.nix:52-95`).

### Fallback (only if p620's evidence check fails; its own PR)

- `hosts/common/nixos/llm-index.nix` gains a host option:

  ```nix
  local.llmIndex.sourceAdoptUuid = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    default = null;
    description = "One-off: accept this filesystem UUID for the source root (#14).";
  };
  ```

  It's passed through as `roots.source.adoptUuid = hostCfg.sourceAdoptUuid;`.
  The upstream Nix module asserts the format at eval time.
- `hosts/p620/nixos/nixarchy.nix` sets it to
  `"bdd8461e-7d6c-42b6-9cfe-39967825dd42"`. razer leaves it `null`.
- A later PR removes the p620 line once `source` is `ok`. The option stays,
  `null` by default.

### Stage 2: the plugin (PR 2, after p620 is `ok`)

All of it goes in `hosts/common/nixos/llm-index.nix`, following
`omarchy-gmessages.nix`:

- **NixOS level:**
  - `imports = [ ./omarchy-enable-once.nix ];`
  - a key binding:

    ```nix
    local.omarchy.keys.extra = [
      {
        key = "SUPER + CTRL + ALT + I";
        description = "llm-index";
        action = "omarchy-shell shell toggle olafkfreund.llm-index '{}'";
      }
    ];
    ```

  - `programs.nixarchy.menu.extraEntries."apps.llm-index"`, with `icon`
    (database glyph), `label = "llm-index"`, a `description` that names
    the key, `aliases` (`llm-index`, `index`, `search index`), and the same
    `action`. This is the same level as podman's entry in
    `omarchy-keys.nix:294`.
- **Inside `home-manager.users.olafkfreund`:**
  - `programs.nixarchy.plugins."olafkfreund.llm-index".src = inputs.nixarchy-llm-index.packages.${pkgs.stdenv.hostPlatform.system}.plugin;`
  - `local.omarchy.enableOnce = [ "olafkfreund.llm-index" ];`
- **Unchanged:** `home.packages = [ cfg.package ]` keeps `llm-index` on
  the session PATH. The plugin calls it with the default config path, which
  is the same file the service reads.
- The module's header comment gains one line about the plugin.

## Alternatives rejected

- **One combined PR and deploy.** It breaks the approved upstream order
  (#14 deployed first) and mixes two risks in one deploy.
- **`adoptUuid` hard-coded in the shared module.** razer would get p620's
  UUID and refuse its own disk. Scoping it to the host keeps it p620-only.
- **Enabling the plugin by writing `shell.json` from activation.** That
  breaks bar IPC (nixarchy `shell-json-reload.md`). `enableOnce` is the
  approved route.
- **A separate `omarchy-llm-index.nix` module.** Hosts that run llm-index
  are exactly the hosts that should have its plugin, so one module keeps
  them from drifting apart.

## Risks

- **p620's first scan in `identity check`** walks about 54k files before the
  verdict. Until then, `source` stays offline and the frozen snapshot still
  serves searches.
- **Evidence below 90%.** Recovery then needs the fallback PR, which costs a
  second deploy.
- **`enableOnce` timing.** The hook runs after the shell starts, and an
  asynchronous rescan can miss the first try. There's no marker in that case,
  so the next login retries. The manual fallback is
  `omarchy plugin enable olafkfreund.llm-index`.
- **The key.** Bindings outside the module's lists aren't checked at build
  time. The live check presses the key.
- **The shell environment.** If the shell's PATH lacks `llm-index`, the
  plugin shows `not installed`. The live check catches it.
- **Hosts:** p620 and razer. p510 doesn't import this module.

## Verification

- **Both PRs:**
  - `just validate`, the full flake check;
  - building p620 and razer;
  - CI green.
- **Stage 1, live:**
  - **p620:**
    - `llm-index status` shows `source` going `identity check`, then
      `ok`, and counts unchanged apart from edits;
    - `share_id` holds `/dev/sdd1`, and `fs_uuid` holds
      `bdd8461e7d6c42b69cfe39967825dd42`;
    - a public MCP search returns a file changed after 2026-11-14.
  - **razer:** both roots stay `ok` with unchanged counts. Note `fs_uuid`
    when it appears.
  - **Clients:** Claude Code, Codex and agy each still list `llm-index`
    and can search.
- **Stage 2, live, p620 then razer, after a re-login:**
  - the plugin is enabled;
  - `SUPER+CTRL+ALT+I` and the menu row open it;
  - its tabs match `llm-index status`;
  - `systemctl --user stop llm-index` gives level `down` within 10 s, and
    Restart from the panel clears it;
  - Open log opens a terminal;
  - `omarchy-shell olafkfreund.llm-index.bar status` shows a level only;
  - the shell journal has nothing from the plugin;
  - a disable in Setup > Plugins survives a re-login.

  These are the #15 checks that were deferred until deploy.

## Rollback

- **Stage 2:** revert PR 2 and redeploy. The plugin is uninstalled. The
  `enableOnce` marker
  (`~/.local/state/nixarchy-local/enabled-once/olafkfreund.llm-index`)
  stays. Delete it before any later re-deploy.
- **Stage 1:** revert PR 1 and redeploy. The older llm-index ignores
  `fs_uuid`, and `share_id` already holds the current device name, so roots
  stay `ok`. Revert PR 2 first if it has landed, because the older input has
  no `.#plugin`.
- **The fallback:** remove `sourceAdoptUuid` before rolling stage 1 back,
  because the older config parser rejects `adopt_uuid`.
