---
status: approved
issue: 2962
intent: intent/2026-11-15-2962-llm-index-plugin.md
---

# Spec: bump llm-index to the identity fix and install its shell plugin

## Design

Two stages, each its own PR, merged to main and then deployed. A conditional
fallback PR may come between them. Everything follows the approved upstream
designs (nixarchy-llm-index #14 and #15).

**Rules for every deploy:**

- from main, after merge;
- announce on the agent bus first;
- p620 with `just p620`, then razer with `just deploy-via-p620 razer`;
- the lead deploys; agents never do;
- p510 doesn't import this module and is never touched.

### Stage 1: the input bump (PR 1)

- `flake.nix:153`: the `nixarchy-llm-index` URL rev goes from `491f256…` to
  `54e0fbebf8a5ce6ea6ccc3056350eb533a95b0f1`, the merge of #17 on main,
  which also contains #16.
- `flake.lock`: `nix flake lock --update-input nixarchy-llm-index` moves only
  that input.
- Nothing else changes.
  - Activation re-registers the public server in Claude Code, Codex and agy,
    because the store path changes (`llm-index.nix:52-95`).
- **Order:** deploy p620 first, then razer.
  - **p620** is a legacy root with a renamed device. #14 row 6 applies: a
    complete scan in `identity check`, then evidence.
  - **razer** is a legacy root with unchanged mountinfo. Row 5 applies: it
    stays `ok`, and `fs_uuid` is recorded only when evidence passes.

### Fallback PR (only if p620's evidence fails)

- `hosts/common/nixos/llm-index.nix` gains a host option:

  ```nix
  sourceAdoptUuid = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    default = null;
    description = "One-off: accept this filesystem UUID for the source root (#14).";
  };
  ```

  It goes under `options.local.llmIndex` and is passed through as
  `roots.source.adoptUuid = hostCfg.sourceAdoptUuid;`. The upstream module
  asserts the format at eval time.
- `hosts/p620/nixos/nixarchy.nix` sets it to
  `"bdd8461e-7d6c-42b6-9cfe-39967825dd42"`. razer leaves it at `null`.
- **Once p620's `source` is `ok`, the whole fallback PR is reverted**: the
  p620 line, the option and the passthrough. The older module (`491f256`)
  doesn't declare `adoptUuid`, so a passthrough left behind, even `null`,
  would break evaluation if stage 1 were ever rolled back.

### Stage 2: the plugin (PR 2, after p620's `source` is `ok`)

All of it goes in `hosts/common/nixos/llm-index.nix`.

- **The file's layout.** It uses explicit `options`/`config`, unlike
  `omarchy-gmessages.nix`:
  - `imports = [ ./omarchy-enable-once.nix ];` goes at the top level, next to
    `options`;
  - the NixOS-level settings go inside `config`, next to the existing
    `home-manager.users.olafkfreund`.
- **NixOS level (inside `config`):**
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

  - `programs.nixarchy.menu.extraEntries."apps.llm-index"`, with:
    - `icon` (database glyph);
    - `label = "llm-index"`;
    - a `description` that names the key;
    - `aliases` (`llm-index`, `index`, `search index`);
    - the same `action`.

    This is the same level as podman's entry in `omarchy-keys.nix:294`.
- **Inside `home-manager.users.olafkfreund`:**
  - `programs.nixarchy.plugins."olafkfreund.llm-index".src = inputs.nixarchy-llm-index.packages.${pkgs.stdenv.hostPlatform.system}.plugin;`
    (upstream exports `packages.x86_64-linux.plugin`);
  - `local.omarchy.enableOnce = [ "olafkfreund.llm-index" ];`
- **Runtime needs** (approved in the intent), each checked live:
  1. **`llm-index` on the shell session's PATH,** with the default config
     path. `home.packages = [ cfg.package ]` (`llm-index.nix:47`) stays, and
     no new PATH wiring is added.
  2. **`omarchy-launch-floating-terminal-with-presentation`** for Open log.
     It's provided by the nixarchy session on both hosts and used by
     rebuild-panel.
  3. **The default Omarchy bar,** which summons bar widgets through
     `shell toggle`. `shell.json`'s `bar` sets no third-party bar plugin.
- **The key chord.** Before the stage 2 deploy, `hyprctl binds -j` must show
  nothing on `I` with modmask 76 (SUPER+CTRL+ALT) on each host. Our binding
  unbinds whatever held the chord, so pressing the key afterwards can't detect
  a collision. On p620 this was already confirmed on 2026-11-15: 0 bindings;
  SUPER+ALT+I (72) is the agent-voice key.
- The module's header comment gains one line about the plugin.

## Alternatives rejected

- **One combined PR and deploy.** It breaks the approved upstream order
  (#14 deployed first) and mixes two risks in one deploy.
- **`adoptUuid` hard-coded in the shared module.** razer would get p620's
  UUID and refuse its own disk.
- **Keeping the fallback option after recovery.** It makes a stage 1
  rollback fail at eval.
- **Enabling the plugin by writing `shell.json` from activation.** That
  breaks bar IPC. `enableOnce` is the approved route.
- **A separate `omarchy-llm-index.nix` module.** Hosts that run llm-index
  are exactly the hosts that should have its plugin.

## Risks

- **p620's first scan in `identity check`** walks about 54k files before the
  verdict. Until then, the frozen snapshot keeps serving searches.
- **Evidence below 90%.** Recovery then needs the fallback PR and a second
  deploy.
- **`enableOnce` timing.** The hook runs after the shell starts, and the
  rescan can miss the first try. With no marker, the next login retries. The
  manual fallback is `omarchy plugin enable olafkfreund.llm-index`.
- **The shell environment.** If the shell's PATH lacks `llm-index`, the
  plugin shows `not installed`. The live check catches it.
- **Hosts:** p620 and razer only.

## Verification

### Every PR

- `just validate`, the full flake check.
- Building p620 and razer.
- CI green.

### Stage 1, live

- **p620:**
  - `llm-index status` shows `source` going `identity check`, then `ok`, with
    counts unchanged apart from edits;
  - a read-only `sqlite3` query of `share_id, fs_uuid` from `roots` in
    `~/.local/state/llm-index/public.db` shows `/dev/sdd1` and
    `bdd8461e7d6c42b69cfe39967825dd42`;
  - a public MCP search finds a file changed after 2026-11-14.
- **razer:**
  - both roots stay `ok`, with unchanged counts;
  - note `fs_uuid` when it appears. It may stay empty, which is fine.
- **Clients:** Claude Code, Codex and agy each still list `llm-index` and can
  search.

### Fallback, only if used

- p620's `source` reaches `ok` with `fs_uuid` `bdd8461e…`.
- razer has no `adopt_uuid` in its generated `config.toml`.
- After the fallback PR is reverted and redeployed, `source` stays `ok`.

### Stage 2, live: p620, then razer, after a re-login

Before the deploy, on each host:

- `hyprctl binds -j` shows modmask 76 free on `I`;
- `shell.json` sets no third-party bar.

After it:

- the plugin is enabled, and the enable-once marker exists;
- `SUPER+CTRL+ALT+I` and the menu row open the panel;
- the tabs match `llm-index status`;
- Refresh shows the busy marker, then updates;
- Open log opens a floating terminal on the journal, which proves the helper
  is there;
- `systemctl --user stop llm-index` gives level `down` within 10 s. Restart
  from the panel, confirmed with the keyboard, clears it. If it doesn't, run
  `systemctl --user start llm-index`;
- the tooltip and `omarchy-shell olafkfreund.llm-index.bar status` show a
  level only;
- the shell journal has nothing from the plugin;
- a disable in Setup > Plugins survives a re-login. Re-enable it afterwards;
- **p620 only (two monitors):** with the panel open, sample every 5 s for 2
  minutes. `pgrep -c -f 'status --json --brief'`, the full-status count and
  the `systemctl --user show llm-index` count each stay at most 1.

## Rollback

- **Stage 2:** revert PR 2, redeploy, and re-login so the shell drops the
  plugin's singleton.
  - The plugin is uninstalled.
  - The `enableOnce` marker
    (`~/.local/state/nixarchy-local/enabled-once/olafkfreund.llm-index`)
    stays. Delete it before any later re-deploy.
- **Stage 1:**
  1. Revert PR 2 first if it landed, because the older input has no
     `.#plugin`.
  2. Revert the whole fallback PR if it's still in, because the older module
     has no `adoptUuid`.
  3. Then revert PR 1 and redeploy.

  The older llm-index ignores `fs_uuid`.
  - Roots whose new identity was accepted stay `ok`, since `share_id` holds
    the current device name.
  - If stage 1 never recovered p620's `source`, it stays `offline` as it was
    before.
