---
status: draft
issue: 3191
spec: spec/2026-11-23-3191-sddm-follows-theme.md
coders:
  1: codex  # small, tricky QML: Loader fallback, MultiEffect mask, the failed-state order
  2: codex  # security-sensitive publisher: no-follow opens, bounded decode, atomic swap
  3: coder  # a short shell script and two Home Manager hook entries, following existing ones
  4: agy    # a large VM test, mostly patterned on tests/session.nix's greeter section
  5: coder  # fixture tests for the two scripts
reviewers:
  - codex   # read of the QML, the publisher and the module diff against this plan
  - agy     # independent read of the same diff
---

# Plan: the SDDM login screen follows the Omarchy theme

## Approved decisions (from the spec)

- **Live:** the next greeter after a theme change shows the theme, with no rebuild. A wallpaper-only change and a
  headless theme set are picked up at the next theme set or the next login.
- **What changes on screen:**
  - background colour, plus the theme's wallpaper behind the form;
  - logo in the accent;
  - lock and field frame in the foreground, bullets drawn in the foreground;
  - a wrong password shows the theme's red until the next key press.
- **Where:** in nixarchy, opt-in through `programs.nixarchy.greeterThemeUser` (nullOr str, default null), modelled
  on `browserThemeUser`. This repo sets it to `olafkfreund` on p620, razer and p510.
- **Data flow:**
  1. As the user: the theme-set.d and post-boot.d hooks run `nixarchy-greeter-sync`, which copies `colors.toml`
     and the wallpaper into `/var/lib/nixarchy-greeter/inbox`, then touches `inbox/ready`.
  2. A path unit starts `nixarchy-greeter-publish.service`. It runs as the static system user
     `nixarchy-greeter`, validates, re-encodes, and publishes a generation under `/var/lib/nixarchy-greeter/out/`.
     `out/current` is swapped in with one atomic symlink rename.
  3. The store theme's `theme.conf.user` and `background` are symlinks into `out/current/`.
- **Fallbacks:** `Main.qml` adds no imports. The new effect code is in `Tinted.qml`, loaded by a `Loader`, with a
  plain PNG fallback on `Loader.Error`. A missing or invalid value gives the built-in default. No image means the
  colour only.
- **Off:** `greeterThemeUser = null`, or `displayManager = false`, adds a tmpfiles `R` rule for
  `/var/lib/nixarchy-greeter`, so nothing lingers after a switch.
- **`omarchy-refresh-sddm`** runs the sync and reports the result.

## Repo facts and traps

- **nixarchy:** work in a worktree of `/mnt/code/Source-home/nixarchy` on a branch for a new nixarchy issue N
  ("feat: the SDDM greeter follows the Omarchy theme"). Never work in the shared checkout; leave it on `main`.
  nixarchy uses its own issue numbers.
- **Install phase size:** `checks.install-phase-budget` caps `pkgs/omarchy/default.nix`'s `installPhase` at
  123,000 bytes. Edge was at 122,513 after nixarchy #1926, with only 487 bytes to spare. **Put all theme edits in
  a new `postInstall` attribute**, not in `installPhase`. `installPhase` already runs `runHook postInstall`
  (line 2083), and only `installPhase` is measured. Explanations go in `pkgs/AGENTS.md`, behind
  `# Why: pkgs/AGENTS.md#<anchor>` pointers.
- **Where the theme comes from:** `installPhase` copies the theme from `${src}/default/sddm/omarchy` to
  `$out/share/sddm/themes/omarchy` (default.nix line 1531):
  - it seeds `currentUser` with a `substituteInPlace` (line 1538);
  - it writes `logo.png` tinted `#a8cd76` (line 1576).

  So the `postInstall` patch is cut against that built tree, not against upstream's file.
- **Pins:** nixarchy main pins Omarchy v4.5.0, and edge pins quattro. Their `Main.qml` is identical today. Build
  both:
  - main: `nix build .#omarchy`;
  - edge: a scratch worktree of `origin/edge` with this change merged in.

  `AGENTS.md` (repo root): a carry is checked under both pins.
- **New sections in `pkgs/AGENTS.md`:** never at the end of the file. Edge appends its own, and #1926 had to move
  around exactly that conflict. Put them after an existing section that main and edge share.
- **This repo:**
  - p510 is never built or deployed without the owner's OK;
  - announce on `#agents:freundcloud.org.uk` before any deploy, then run with `AGENT_BUS_ANNOUNCED=1`;
  - deploy razer with `just deploy-via-p620 razer`;
  - write PR bodies and commit messages to files.

## Steps

0. **Issue and worktree** (lead). Open nixarchy issue N, then:

   ```bash
   git -C /mnt/code/Source-home/nixarchy worktree add ../nixarchy-N -b feat/N-greeter-theme origin/main
   ```

1. **The SDDM theme** (codex). New files:
   - `pkgs/omarchy/N-greeter-theme.patch`, against `share/sddm/themes/omarchy` as `installPhase` leaves it;
   - `pkgs/omarchy/greeter/Tinted.qml`;
   - a `postInstall` attribute in `pkgs/omarchy/default.nix`.

   What changes:
   - **`metadata.desktop`:** add `ConfigFile=theme.conf`.
   - **`theme.conf`:** `[General]` with
     - `background=#1a1b26`;
     - `foreground=#a9b1d6`, today's lock and bullet colour;
     - `accent=#a8cd76`, the `logo.png` tint at line 1576;
     - `failed=#f7768e`, the `*-failed.png` red.

     Confirm the foreground and failed values from the PNG images with `magick <png> -alpha off -scale 1x1
     -format '%[pixel:p{0,0}]' info:`, and record any change in this plan.
   - **`Main.qml`:**
     - `function pick(key, fallback)`: return `config[key]` when it matches `/^#[0-9a-fA-F]{6}$/`, else
       `fallback`.
     - The root `color` becomes `pick("background", "#1a1b26")`.
     - Behind the form, add `Image { source: "background"; asynchronous: true; fillMode:
       Image.PreserveAspectCrop; sourceSize.width: root.width; sourceSize.height: root.height; visible: status ===
       Image.Ready }`.
     - Behind the `Column`, add a translucent `Rectangle` in the background colour, with opacity about 0.75 and
       padding of about 24 px.
     - Replace the logo, lock and entry `Image`s each with a `Loader { id: x; source: "Tinted.qml"; onLoaded: {
       item.src = ...; item.tint = ...; item.width/height = ... } }`. Next to each Loader, add a fallback `Image`
       with today's source (including the `*-failed.png` switch), `visible: x.status === Loader.Error`. Keep each
       original's size rules: the logo's `Math.min(sourceSize.width, root.width * 0.8)` with
       `PreserveAspectFit`; the lock and entry at their PNG sizes.
     - The bullet `Repeater` delegate becomes a 7×7 `Rectangle` with `radius: 3.5` and `color:
       pick("foreground", ...)`.
     - **Failed state:** in `onLoginFailed`, set `password.text = ""` first, then `root.loginFailed = true`. Move
       the reset from `onTextChanged` to `Keys.onPressed`, for any key except Return and Enter. While failed,
       the lock and frame tint is `pick("failed", ...)`.
   - **`Tinted.qml`:**
     - `import QtQuick` and `import QtQuick.Effects`;
     - properties `src` and `tint`;
     - an `Image { id: shape; source: src; visible: false; layer.enabled: true }`;
     - a `Rectangle { id: fill; color: tint; anchors.fill: parent; visible: false; layer.enabled: true }`;
     - `MultiEffect { anchors.fill: parent; source: fill; maskEnabled: true; maskSource: shape }`.
   - **`postInstall`:**

     ```bash
     # Why: pkgs/AGENTS.md#the-greeter-follows-the-omarchy-theme-N
     patch -d "$out/share/sddm/themes/omarchy" -p1 --forward --fuzz=0 < ${./N-greeter-theme.patch}
     install -m644 ${./greeter/Tinted.qml} "$out/share/sddm/themes/omarchy/Tinted.qml"
     ln -s /var/lib/nixarchy-greeter/out/current/theme.conf "$out/share/sddm/themes/omarchy/theme.conf.user"
     ln -s /var/lib/nixarchy-greeter/out/current/background.png "$out/share/sddm/themes/omarchy/background"
     ```

   - Add the `pkgs/AGENTS.md` section that the pointer names, after a shared section.

   → **Verify:**
   - `nix build .#omarchy` passes, and the tree has both symlinks, `Tinted.qml` and the patched files;
   - `checks.install-phase-budget` passes, with `installPhase` unchanged;
   - the same two checks pass in the scratch edge worktree;
   - QML errors are caught in step 4.

   **Traps:**
   - `--fuzz=0` and `--forward`, as for every carried patch;
   - don't touch `installPhase`;
   - `Tinted.qml` must not be imported by `Main.qml`; it is only loaded by URL.

2. **The publisher and the NixOS module** (codex).
   - **`pkgs/nixarchy-greeter-publish/`,** a Python 3 script on the stdlib, with ImageMagick on its `PATH`, exposed
     as `pkgs.nixarchy-greeter-publish`. It does this:
     1. For each of `inbox/colors.toml` and `inbox/background`, `os.open` with
        `O_RDONLY|O_NOFOLLOW|O_NONBLOCK|O_CLOEXEC`, then `fstat`. Require `S_ISREG`, and a size of at most 64 KiB
        and 50 MiB respectively. Read at most that size from the open descriptor. Any failure: treat that file
        as absent.
     2. Parse `colors.toml` with `tomllib`. Keep `background`, `foreground` and `accent`, plus `red` stored as
        `failed`, only when a value is a `str` matching `^#[0-9a-fA-F]{6}$`.
     3. Image: pipe the bytes to

        ```bash
        magick -limit memory 256MiB -limit map 512MiB -limit width 16KP -limit height 16KP \
          -limit time 30 - -auto-orient -resize '3840x2160>' -strip png:<tmp>
        ```

        with a 60 s `subprocess` timeout. A non-zero exit or a timeout means no image.
     4. Make `out/gen-<unix_ns>/` with mode 0755. Write `theme.conf` (`[General]` plus the kept keys) and, if any,
        `background.png`, both mode 0644. Then `os.symlink(gen, out/.current-new)` and
        `os.replace(out/.current-new, out/current)`. Remove every other `gen-*` except the new one and the one
        `current` pointed to before.
     5. Exit 0 on every handled failure. `current` is unchanged unless step 4 completed.
   - **`modules/nixos.nix`:** add `greeterThemeUser` after `browserThemeUser` (line 494), with the same type and
     a description that says:
     - other users see this user's wallpaper and colours at login;
     - it needs `displayManager`.

     Under `config`, with `on = cfg.displayManager && cfg.greeterThemeUser != null`:
     - `users.users.nixarchy-greeter = { isSystemUser = true; group = "nixarchy-greeter"; }`, and its group.
     - `systemd.tmpfiles.rules`:
       - when `on`:
         - `d /var/lib/nixarchy-greeter 0755 root root -`
         - `d /var/lib/nixarchy-greeter/inbox 0755 <user> - -`
         - `d /var/lib/nixarchy-greeter/out 0755 nixarchy-greeter nixarchy-greeter -`
       - when off: `R /var/lib/nixarchy-greeter`.
     - `systemd.paths.nixarchy-greeter-publish`: `wantedBy = [ "multi-user.target" ]`, and
       `pathConfig.PathChanged = "/var/lib/nixarchy-greeter/inbox/ready"`.
     - `systemd.services.nixarchy-greeter-publish`, `Type=oneshot`, with:
       - `User` and `Group` `nixarchy-greeter`;
       - `ProtectSystem=strict`, `ProtectHome=true`, `NoNewPrivileges=true`, `PrivateTmp=true`,
         `PrivateNetwork=true`;
       - `ReadWritePaths=/var/lib/nixarchy-greeter/out`;
       - `MemoryMax=1G`, `RuntimeMaxSec=120`;
       - `RestrictAddressFamilies=none`, `LockPersonality`, `ProtectKernel*`, `SystemCallArchitectures=native`;
       - `ExecStart=${pkgs.nixarchy-greeter-publish}/bin/nixarchy-greeter-publish`.

       Also start it once at boot (`wantedBy = [ "multi-user.target" ]`), so an inbox filled before a reboot is
       published.

   → **Verify:**
   - `nix build .#nixarchy-greeter-publish`;
   - `nix eval` of a test configuration with the option on and off (the units and tmpfiles rules appear, or the
     `R` rule appears);
   - step 5's tests.

   **Trap:** a static user, not `DynamicUser`, because the greeter must traverse into `out/`. The repo's hardening
   rules otherwise apply in full.

3. **The sync, the hooks and the refresh command** (coder).
   - **`pkgs/nixarchy-greeter-sync/`,** a bash `writeShellApplication` with `coreutils` and `util-linux` (for
     `flock`) in `runtimeInputs`. It does this:
     1. `inbox=/var/lib/nixarchy-greeter/inbox`. `[ -d "$inbox" ] && [ -w "$inbox" ] || exit 0`.
     2. `exec 9>"${XDG_RUNTIME_DIR:-/tmp}/nixarchy-greeter-sync.lock"; flock 9`.
     3. `trap 'rm -f "$inbox"/.tmp.*' EXIT`.
     4. Copy `colors.toml`. `src=$HOME/.local/state/omarchy/current/theme/colors.toml`. If it is a regular file,
        `cp -- "$src" "$inbox/.tmp.colors"`, `chmod 0644`, then `mv -f` to `colors.toml`. Otherwise remove
        `colors.toml`.
     5. Copy the background. `bg=$(readlink -f "$HOME/.local/state/omarchy/current/background")`. If it is a
        regular file whose extension, in lower case, is png, jpg, jpeg, gif, bmp or webp, copy it the same way to
        `background`. Otherwise remove `background`.
     6. `touch "$inbox/ready"`.
   - **`modules/home.nix`,** next to the `theme-set.d/cursor` entry (line 1570). Add two files, one script each:
     - `"omarchy/hooks/theme-set.d/20-greeter"`
     - `"omarchy/hooks/post-boot.d/20-greeter"`

     Each is executable, with text `#!/usr/bin/env bash` and
     `exec ${pkgs.nixarchy-greeter-sync}/bin/nixarchy-greeter-sync`.
     They are always installed; the script exits 0 when the feature is off.
   - **`pkgs/omarchy/nix-bin/omarchy-refresh-sddm`:**
     - run `nixarchy-greeter-sync`;
     - if `systemctl cat nixarchy-greeter-publish.path` fails, say the option is off and name
       `programs.nixarchy.greeterThemeUser`;
     - otherwise wait up to 10 s for `readlink /var/lib/nixarchy-greeter/out/current` to change, then say whether
       the next login screen uses the theme.

   → **Verify:** `nix build` of both packages, `shellcheck` clean, and step 5's tests.

4. **The VM check** (agy): new `tests/greeter-theme.nix`, registered in `flake.nix` next to `session` (line 2054),
   with the same arguments. It follows `tests/session.nix`'s greeter section (lines 558–600):
   `loginctl ... | grep greeter`, retried screenshots, `send_chars`, and the journal check for a successful
   authentication. The node sets `programs.nixarchy.greeterThemeUser` to the test user and uses Hyprland as the
   greeter compositor, as in `hosts/common/nixos/omarchy-sddm.nix` in nixos_config. Cases, each followed by
   `systemctl restart display-manager` and a login:
   1. **No theme data:** check the centre-top pixel of the screenshot (a PIL read in the test driver) is
      `#1a1b26` within a tolerance.
   2. **Theme published:** write a `colors.toml` with `background = "#ff0000"` and a 64×64 blue PNG into the
      inbox, and touch `ready`. Then wait for the service to be inactive, and for `out/current/theme.conf` to
      contain `#ff0000`. Expect blue pixels from the wallpaper, and the panel colour around the form.
   3. **Bad colour:** `background = "red;"`. Expect `#1a1b26`, and login works.
   4. **Hostile inbox:** a FIFO at `inbox/background`, `colors.toml` as a symlink to `/etc/shadow`, and a 60 MiB
      file. Expect the service to finish within its timeout, `out/current` unchanged, and login to work.
   5. **Broken `Tinted.qml`:** override the package with a `Tinted.qml` holding a syntax error. Expect the PNG
      fallback drawn (OCR not blank), and login works.
   6. **Wrong password:** type a wrong password, then take a screenshot. Expect the theme's `failed` red in the
      lock's area.

   → **Verify:** `nix build .#checks.x86_64-linux.greeter-theme -L` passes, on p620 (nixarchy's VM checks run
   there; announce on the bus first).

   **Trap:** don't add it to the cheap-checks list. It is a VM check, like `session`.

5. **Script tests** (coder):
   - `tests/greeter-sync.nix`: a `runCommand` with a fake `$HOME` and inbox. It covers:
     - a valid theme;
     - a missing `colors.toml`;
     - a video background;
     - an uppercase `.PNG`;
     - two runs started together (the final inbox matches the last one);
     - a missing inbox and a read-only inbox (exit 0, nothing written).
   - `tests/greeter-publish.nix`: runs the publisher against a temporary root, with the paths taken from an
     environment variable that the script reads only when it is set; default `/var/lib/nixarchy-greeter`. It
     covers:
     - valid input;
     - bad hex;
     - a non-string value;
     - a symlink;
     - a FIFO;
     - an oversized file;
     - a corrupt image;
     - a valid JPEG, which comes out as PNG at most 3840×2160;
     - only two generations kept;
     - `current` unchanged on every failure.

   Register both among the cheap checks in `flake.nix`.

   → **Verify:** both pass with `nix build .#checks.x86_64-linux.<name>`.

6. **nixarchy PR and edge** (lead).
   - Review the diff against steps 1–5, and run the Codex and agy reviews.
   - Open the PR: "Closes N". Merge it when CI is green.
   - Dispatch `omarchy-edge` after the bus announcement, and confirm edge contains the merge commit. Merged on
     main does not mean published to edge.

7. **This repo** (lead), in this worktree after edge publishes:
   - Bump nixarchy: `nix flake update nixarchy`.
   - Add `programs.nixarchy.greeterThemeUser = "olafkfreund";` to `hosts/p620/nixos/nixarchy.nix`,
     `hosts/razer/nixos/nixarchy.nix` and `hosts/p510/nixos/nixarchy.nix`, next to the other `programs.nixarchy`
     settings.
   - `just check-syntax`, `just test-host p620` and `just test-host razer`.
   - Open the PR, linking intent, spec and plan, and merge it.

8. **Deploy and check** (lead):
   - razer first, with `just deploy-via-p620 razer`, then p620 with `just p620`. Bus announcement before each.
   - On each host:
     - `systemctl status nixarchy-greeter-publish.path` is active;
     - `omarchy theme set` to a light theme, then `readlink /var/lib/nixarchy-greeter/out/current` changes;
     - the owner logs out: the greeter shows the theme's colours and wallpaper;
     - a wrong password shows red;
     - the login works;
     - repeat with a dark theme.
   - p510 only after the owner says OK.

## Tests

| Check | Expected |
| --- | --- |
| `nix build .#omarchy`, main and the scratch edge worktree | pass |
| `checks.install-phase-budget`, both pins | pass, `installPhase` unchanged |
| `checks.greeter-sync`, `checks.greeter-publish` | pass |
| `checks.greeter-theme` (VM, p620) | 6 cases pass |
| `just test-host p620`, `just test-host razer` | pass |
| razer and p620 greeter, light and dark theme | theme shown, login works |

## Rollback

- **This repo:** revert the step-7 PR to restore the previous pin and drop `greeterThemeUser`. Or, faster, set
  `greeterThemeUser = null` on a host. Its next switch removes `/var/lib/nixarchy-greeter`, and the greeter goes
  back to today's look.
- **A greeter that will not start:** choose the previous generation at boot, then revert.
- **nixarchy:** revert the PR. The option goes away, and the theme goes back to upstream's files.
