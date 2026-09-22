---
status: draft
issue: 1973
intent: intent/2026-09-23-1973-omacards-declarative.md
---

# Spec: declare OmaCards on p620, with its Hyprflip helper and shortcuts

Stacked on #1972 (#1967) and #1969; it merges after both. Decisions taken from the
approved intent's open questions: pin OmaCards with a **flake input**, take
upstream's **combined O key**, and handle `omarchy plugin update` with a comment
(the check below shows it needs nothing more).

## Design

Everything goes into the existing `hosts/common/nixos/omarchy-hyprflip.nix`
(#1967), guarded by the same `attrByPath [ "programs" "hyprflip" ]`. OmaCards has
no meaning without Hyprflip, so one module owns both. The module gains `inputs`
in its arguments. No new import line is needed in `hosts/p620/nixos/nixarchy.nix`.

### 1. The plugin, pinned

- `flake.nix`: `omacards = { url = "github:nocstah/omacards"; flake = false; };`,
  the same shape as the existing `flake = false` input for the Claude-Skills
  catalogue. The lock must resolve to the reviewed commit `97a331e`. If upstream
  has moved on by implementation time, the new commits are reviewed before the
  lock accepts them.
- In the module:
  `home-manager.users.olafkfreund.programs.nixarchy.plugins."io.github.nocstah.omacards".src = inputs.omacards;`
  This is the pattern `nixarchy.pkg` and `nixarchy.distrobox` use on p620.
  nixarchy validates the `manifest.json` at build time and links the plugin at
  activation.
- The enabled state and the bar entry (`shell.json`, last item on the right)
  are keyed by the id, which does not change, so both carry over.
- `omarchy plugin update` needs no guard. It only acts on plugin folders with a
  `.git` (`omarchy-plugin-update` lines 111 and 116), and a `flake = false` store
  path has none, so the Nix-managed plugin is skipped automatically. A comment
  says so and says that updates are `nix flake update omacards`.

### 2. The helper, from the pinned `hyprflip` input

- `home.file.".local/lib/hyprflip/<f>".source = "${inputs.hyprflip}/scripts/<f>"`
  for `control.py`, `workflow.py`, `shortcuts.py` **and `setup.py`**. `setup.py`
  is new: the C and L shortcuts run it, and it imports only `workflow`. The four
  files are the whole import set (`control` → `workflow`, `shortcuts`;
  `shortcuts` → `workflow`; `setup` → `workflow`). Standard library only, plus
  the `gio` CLI.
- One input now moves the Hyprland plugin, hy3 and the helper together.
- The three hand-copied regular files are taken over through Home Manager's
  `backupCommand` (moved into `~/.hm-backups/`).

### 3. Protocol mismatch fails the build

An `assertions` entry, evaluated purely, with no build step:

- the helper side: `builtins.match` on `PROTOCOL = ([0-9]+)` in
  `${inputs.hyprflip}/scripts/control.py`;
- the OmaCards side: `builtins.match` on `data.protocol !== ([0-9]+)` in
  `${inputs.omacards}/Service.qml`;
- the assertion is that they are equal (both `1` today), with a message naming
  both revisions.

If either pattern stops matching (upstream rewrote it), the assertion fails with
a message saying the check needs updating. It never passes silently.

### 4. The shortcuts: two more generated Lua files, and a setup block

Upstream's `install-setup.py` would drop three files into `~/.config/hypr/`. They
are generated here instead, copied verbatim from the pinned `hyprflip` input
(`examples/`):

| File (`~/.config/hypr/`) | From | Role |
| --- | --- | --- |
| `hyprflip-shortcuts.lua` | `examples/shortcuts.lua` | `bind`/`unbind` wrapper; reads user overrides from `~/.local/state/hyprflip/shortcuts` |
| `hyprflip-preferences.lua` | `examples/preferences.lua` | reads transition and duration from `~/.local/state/hyprflip/` |
| setup block (appended to `hyprflip.lua`) | `examples/containers-setup.lua` | O (unfold, fold or create), C (edit card), L (open saved card), Space (hold to peek) |

- `hyprflip-shortcuts.lua` and `hyprflip-preferences.lua` stay separate files,
  because they are `require`d as modules by name.
- The setup block goes **inline at the end** of the generated `hyprflip.lua`,
  after the hy3 block. That keeps #1967's one-loader design and guarantees the
  order upstream needs ("after the other Hyprflip bindings"). Its `unbind` of O
  removes #1967's unfold bind before rebinding it, so no two binds compete for O.
- It is appended only when `containers.enable` is set, the upstream variant
  `install-setup.py` picks when containers are present.
- **User settings stay mutable.** Transition, duration and custom shortcuts live
  in `~/.local/state/hyprflip/`. OmaCards' helper writes them, and these files
  read them at config parse. Nix owns the code, you own the state.
- **Behaviour change to note:** today the `pcall(require, "hypr.hyprflip-shortcuts")`
  at the top of `hyprflip.lua` fails and falls back to `hl`. Once the module
  exists, the core M/S/F/U/Escape binds go through its `bind`. By default they
  are the same keys. The difference is that OmaCards' settings can now remap
  them, which is upstream's intent.

### 5. Cutover (the trap from the intent)

nixarchy's activation keeps a real directory under a declared id. Right before
the switch:

- Check that `~/.local/state/hyprflip/` has not appeared. If it has, it holds
  saved cards; it is never touched, because it is not in Home Manager, so it
  survives either way. The check makes sure that is recorded.
- `mv ~/.config/omarchy/plugins/io.github.nocstah.omacards ~/.config/omarchy/plugins/.io.github.nocstah.omacards.bak-1973`.
  The dot prefix hides it from the shell's plugin scan, which excludes hidden
  top-level entries.
- Switch. Activation links the store path in under the same id.

That is two shell reloads close together (the `mv`, then the link). The bar
freezes about 40 s each, which is the known #710 cost.

### When each part takes effect

- The **plugin link and the helper**: at the switch. The shell picks the plugin
  up on its reload.
- The **shortcut Lua**: at the **next re-login**, the same as #1967, because
  there is no `hyprctl reload` on the live session.

## Alternatives rejected

- **`fetchFromGitHub` with a hash in the module:** rejected by the intent
  decision. It stays invisible to lock bumps and `check-updates`.
- **Run upstream `install-setup.py`:** it rewrites `hyprland.lua` and bindings in
  `~/.config/hypr/`, which Nix manages in part here.
- **`OMACARDS_BACKEND` pointing at a store path, instead of files in
  `~/.local/lib`:** the variable must reach the Omarchy shell's environment. That
  is session environment set at login, and it cannot help C and L, which run
  `~/.local/lib/hyprflip/setup.py` by fixed path.
- **Separate `hyprflip-setup.lua` required from `hyprflip.lua`:** one more
  `require` and one more ordering to keep. Inline gives the order by
  construction, as in #1967.
- **Keep #1967's unfold-only O:** rejected by the intent decision. Upstream's O
  is a superset.
- **A new module file:** OmaCards only works with Hyprflip, and one guard and
  one owner are simpler.

## Risks

- **Silent no-op if the cutover `mv` is skipped.** Mitigation: the plan checks
  afterwards that the plugin path is a **symlink into the store**, not a
  directory.
- **Two bar freezes (~40 s each)** during cutover. Known cost. Announced on the
  bus first.
- **The core binds change route** (`hl` → the shortcuts module). They are the
  same keys by default. Mitigation: a live check after re-login that
  M/S/F/U/Escape still work.
- **An upstream rename** of a helper file or an example Lua: `home.file.source`
  on a missing path fails the build. The protocol assertion fails with a clear
  message.
- **Rollback of the plugin:** `mv` the `.bak-1973` folder back and roll back the
  generation.
- **Only p620 changes.** The same guard as #1967, so razer and p510 must still
  evaluate.

## Verification

1. **Build:** the p620 toplevel builds. razer and p510 evaluate.
2. **Pins:** `flake.lock`'s `omacards` node is `97a331e` (or a reviewed newer
   commit).
3. **The protocol assertion bites:** temporarily point the OmaCards side at a
   fake `2` and evaluation fails with the message. Revert. Not committed.
4. **Generated files:**
   - `hyprflip.lua` still starts with the #1967 content byte for byte (core
     sha `8fd141c3…`, then the hy3 block), followed by the setup block.
   - `hyprflip-shortcuts.lua` and `hyprflip-preferences.lua` equal the input's
     `examples/` files.
   - The four helper files equal the input's `scripts/`.
5. **Nested session**, as in #1967, with the built libraries **and** the
   generated Lua: `configerrors` empty, and the O, C, L and Space binds
   registered with upstream's descriptions.
6. **After the switch:**
   - the plugin path is a symlink into the store;
   - the hand clone sits in `.bak-1973`;
   - the helper files are Home Manager links;
   - `listPlugins` shows OmaCards enabled;
   - the helper `snapshot` gives protocol 1 and `containers: true`;
   - no failed units.
7. **After re-login:**
   - the C, L and Space binds are registered, and O has the combined
     description;
   - the M/S/F/U/Escape and H/V/E binds still work;
   - `configerrors` is empty;
   - the OmaCards panel opens from the bar icon, and C opens the editor.
