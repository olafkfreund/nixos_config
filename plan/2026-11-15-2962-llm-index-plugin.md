---
status: draft
issue: 2962
spec: spec/2026-11-15-2962-llm-index-plugin.md
coders:
  1: coder   # mechanical: one rev in flake.nix and a single-input lock update
  2: coder   # small conditional option plus one host line; only if the fallback is needed
  3: agy     # mechanical Nix wiring in one module, following omarchy-gmessages.nix
reviewers:
  - codex    # independent read of each PR's diff against this plan
  - agy      # second read; checks the Nix placement against the omarchy modules
---

# Plan: bump llm-index to the identity fix and install its shell plugin

Self-contained summary of the approved spec
(`spec/2026-11-15-2962-llm-index-plugin.md`).

- **Repo:** nixos_config.
- **PR 1:** these artifacts plus step 1, on `feat/2962-llm-index-plugin`
  (worktree `/home/olafkfreund/.config/nixos-llmidx-plugin`).
- **Fallback PR (step 2, only if needed):** `fix/2962-llm-index-adopt`.
  The PR that removes it again comes after recovery.
- **PR 2 (step 3):** `feat/2962-llm-index-plugin-ui`. It's made from main
  **only after p620's `source` is `ok`**.
- Each branch is a worktree next to `~/.config/nixos`.

## Approved decisions

**Rules for every deploy:**

- from `~/.config/nixos` on main, after merge;
- announce on the agent bus first (`AGENT_BUS_ANNOUNCED=1`);
- p620 with `just p620`, then razer with `just deploy-via-p620 razer`;
- the lead deploys and agents never do;
- p510 is never touched.

**The rest:**

- **Stage 1** changes the llm-index input pin only, to
  `54e0fbebf8a5ce6ea6ccc3056350eb533a95b0f1`.
- **The fallback**, if used:
  - `local.llmIndex.sourceAdoptUuid` (`nullOr str`, default `null`), passed
    through as `roots.source.adoptUuid`;
  - p620 sets `"bdd8461e-7d6c-42b6-9cfe-39967825dd42"`;
  - the **whole** fallback PR is reverted once `source` is `ok`.
- **Stage 2** goes in `hosts/common/nixos/llm-index.nix`:
  - `imports = [ ./omarchy-enable-once.nix ]` at the top level;
  - inside `config`: `local.omarchy.keys.extra` (`SUPER + CTRL + ALT + I`,
    description "llm-index", action
    `omarchy-shell shell toggle olafkfreund.llm-index '{}'`) and
    `programs.nixarchy.menu.extraEntries."apps.llm-index"` (icon, label
    `llm-index`, a description naming the key, aliases `llm-index`, `index`
    and `search index`, the same action);
  - inside `home-manager.users.olafkfreund`:
    `programs.nixarchy.plugins."olafkfreund.llm-index".src = inputs.nixarchy-llm-index.packages.${pkgs.stdenv.hostPlatform.system}.plugin;`
    and `local.omarchy.enableOnce = [ "olafkfreund.llm-index" ];`;
  - `home.packages = [ cfg.package ]` stays;
  - the header comment gains one line about the plugin.
- **No `shell.json` writes from Nix.**

## Steps

The check for steps 1 to 3, from the step's worktree:

```bash
nix build .#nixosConfigurations.p620.config.system.build.toplevel --no-link && nix build .#nixosConfigurations.razer.config.system.build.toplevel --no-link
```

The lead then runs `just validate`. Traps for every step:

- the repo's pre-commit runs nixpkgs-fmt and deadnix, so keep the files
  clean;
- agents never stage, commit, push, deploy, switch or restart, and never
  work on `main` or in `~/.config/nixos`.

1. **Input bump** in `flake.nix:153` and `flake.lock`.
   - Set the rev to `54e0fbebf8a5ce6ea6ccc3056350eb533a95b0f1`.
   - Run `nix flake lock --update-input nixarchy-llm-index`.
   - `git diff flake.lock` shows only the `nixarchy-llm-index` node changed.

   → verify with the check above, and:

   ```bash
   nix eval --raw .#nixosConfigurations.p620.config.home-manager.users.olafkfreund.services.llm-index.package
   ```

   Its store path differs from today's.

   Trap: no other input moves.

2. **Fallback, only if p620's evidence fails after stage 1.**
   - In `hosts/common/nixos/llm-index.nix`, add `sourceAdoptUuid` under
     `options.local.llmIndex`, and pass
     `adoptUuid = hostCfg.sourceAdoptUuid;` into `roots.source`.
   - In `hosts/p620/nixos/nixarchy.nix`, set
     `local.llmIndex.sourceAdoptUuid = "bdd8461e-7d6c-42b6-9cfe-39967825dd42";`
     next to `sourcePath`.

   → verify with the check above, and:

   ```bash
   nix eval .#nixosConfigurations.razer.config.home-manager.users.olafkfreund.services.llm-index.roots.source.adoptUuid
   ```

   It gives `null`.

   Trap: it's removed again by reverting this whole PR once `source` is
   `ok`.

3. **Plugin wiring** in `hosts/common/nixos/llm-index.nix`, as in Approved
   decisions. Follow `hosts/common/nixos/omarchy-gmessages.nix`, but respect
   this file's explicit `options`/`config` layout.

   → verify with the check above, and:

   ```bash
   nix eval --json .#nixosConfigurations.p620.config.home-manager.users.olafkfreund.programs.nixarchy.plugins --apply builtins.attrNames
   ```

   It contains `olafkfreund.llm-index`.

   Traps:
   - the keys module fails the build on a duplicate chord;
   - don't touch the MCP registration activation.

## Tests (lead)

**Before stage 2, on each host:**

- `hyprctl binds -j` shows nothing on `I` with modmask 76. p620 was free on
  2026-11-15.
- `shell.json` sets no third-party bar.

**Stage 1, live:**

- **p620:**
  - `llm-index status` shows `source` going `identity check`, then `ok`,
    with counts unchanged apart from edits;
  - a read-only `sqlite3` query of `share_id, fs_uuid` from `roots` in
    public.db shows `/dev/sdd1` and `bdd8461e7d6c42b69cfe39967825dd42`;
  - a public MCP search finds a file changed after 2026-11-14.
- **razer:** both roots stay `ok` with unchanged counts. Note `fs_uuid`.
- **Clients:** Claude Code, Codex and agy still list `llm-index` and can
  search.

**Fallback, if used:**

- p620 reaches `ok` with that UUID;
- razer's `config.toml` has no `adopt_uuid`;
- after the revert and redeploy, `source` stays `ok`.

**Stage 2, live: p620, then razer, after a re-login:**

- the plugin is enabled and the marker exists;
- the key and the menu row open the panel;
- the tabs match `llm-index status`;
- Refresh shows the busy marker;
- Open log opens a floating terminal on the journal;
- `systemctl --user stop llm-index` gives `down` within 10 s. Restart from
  the panel (keyboard confirm) clears it. Otherwise run
  `systemctl --user start llm-index`;
- the tooltip and `omarchy-shell olafkfreund.llm-index.bar status` show a
  level only;
- the shell journal has nothing from the plugin;
- a disable survives a re-login, then re-enable it;
- **p620:** with the panel open, sample every 5 s for 2 minutes.
  `pgrep -c` of brief, full and `systemctl --user show llm-index` each stays
  at most 1.

**Reviews:** before each PR, fresh Codex and agy reviews, read-only, of its
diff against this plan.

## Rollback

- **Stage 2:** revert PR 2, redeploy, and re-login. Delete the
  `enabled-once/olafkfreund.llm-index` marker before any later re-deploy.
- **Stage 1:** revert in this order, then redeploy:
  1. PR 2, if it landed;
  2. the whole fallback PR, if it's still in;
  3. PR 1.

  Roots whose new identity was accepted stay `ok`. A `source` that never
  recovered stays `offline`.
