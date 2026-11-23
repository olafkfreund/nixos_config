---
status: draft
issue: 3191
spec: spec/2026-11-23-3191-sddm-follows-theme.md
coders:
  1: codex  # small, tricky QML: Binding-driven Loader slots, MultiEffect mask, the failed-state order
  2: codex  # security-sensitive publisher: no-follow opens, owner check, bounded decode, atomic swap
  3: coder  # a short shell script, two Home Manager hook entries and the refresh stub, following existing ones
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
- **On screen:**
  - background colour, plus the theme's wallpaper behind the form;
  - logo in the accent;
  - lock and field frame in the foreground, bullets drawn in the foreground;
  - a wrong password shows the theme's red until the next key press.
- **Where:** in nixarchy, opt-in through `programs.nixarchy.greeterThemeUser` (nullOr str, default null), modelled
  on `browserThemeUser`. This repo sets it to `olafkfreund` on p620, razer and p510.
- **Data flow:**
  1. As the user: the theme-set.d and post-boot.d hooks run `nixarchy-greeter-sync`. It copies `colors.toml` and
     the wallpaper into `/var/lib/nixarchy-greeter/inbox`, then renames a fresh `ready` file into place.
  2. A path unit starts `nixarchy-greeter-publish.service` as the static system user `nixarchy-greeter`. It
     validates and re-encodes, then publishes a generation under `/var/lib/nixarchy-greeter/out/`. `out/current`
     is swapped in with one atomic symlink rename.
  3. The store theme's `theme.conf.user` is a symlink to `out/current/theme.conf`.
- **Fallbacks:** `Main.qml` adds no imports. The effect code is in `Tinted.qml`, loaded by a `Loader`, with a plain
  PNG fallback on `Loader.Error`. A missing or invalid value gives the built-in default. No image means the colour
  only.
- **Off:** `greeterThemeUser = null`, or `displayManager = false`, adds a tmpfiles `R` rule for
  `/var/lib/nixarchy-greeter`.
- **`omarchy-refresh-sddm`** runs the sync and reports the result.

### Clarifications of the spec (from the plan review)

These resolve points the spec left open or contradictory. They change no decision above.

- **Failures, by kind.** The spec said both "any failure gives a generation with no image" and "any failure
  leaves `current` as it was". Resolved by kind:

  - **Content** (publish, minus the bad part): an absent file, a key that is missing or not `#rrggbb`, or an
    image that fails to decode. `current` moves to a generation without it; removing a wallpaper must clear it.
  - **Unsafe** (abort, `current` unchanged): a symlink, a FIFO or other non-regular file, an oversized file, a file
    not owned by `greeterThemeUser`, a TOML parse error, or a write error.

- **One snapshot per greeter.** SDDM reads `theme.conf.user` once at greeter start, but QML loads an image later
  and asynchronously. A publish in between could pair old colours with a new wallpaper. So the wallpaper is no
  longer a fixed symlink:
  - `theme.conf` names its own generation's image (`wallpaper=gen-<ns>/background.png`);
  - QML builds the path from that validated value;
  - the publisher keeps the previous generation, so the path a running greeter resolved still exists.

  The spec's `background` symlink is dropped.

## Repo facts and traps

- **nixarchy:** work in a worktree of `/mnt/code/Source-home/nixarchy` on a branch for a new nixarchy issue N
  ("feat: the SDDM greeter follows the Omarchy theme"). Never work in, or check out a branch in, the shared
  checkout; leave it on `main`. nixarchy uses its own issue numbers.
- **Install phase size:** `checks.install-phase-budget` caps `pkgs/omarchy/default.nix`'s `installPhase` at
  123,000 bytes. Edge was at 122,513 after nixarchy #1926. **Put every theme edit in a new `postInstall`
  attribute**, not in `installPhase`. `installPhase` already runs `runHook postInstall` (line 2083), and only
  `installPhase` is measured. Explanations go in `pkgs/AGENTS.md`, behind `# Why: pkgs/AGENTS.md#<anchor>`
  pointers.
- **Where the theme comes from:** `installPhase` copies the theme from `${src}/default/sddm/omarchy` to
  `$out/share/sddm/themes/omarchy` (default.nix line 1531):
  - it seeds `currentUser` with a `substituteInPlace` (line 1538);
  - it writes `logo.png` tinted `#a8cd76` (line 1576).

  So the patch is cut against that built tree. In the built `Main.qml`:
  - the root is 640×480 until SDDM resizes it (lines 6–7);
  - the logo is sized from its `sourceSize` (lines 40–41);
  - the lock is 34×38 (lines 51–53);
  - the entry container takes `entry`'s implicit size, 286×48 (lines 58–66);
  - bullets are 7×7 (lines 79–80).
- **Default colours,** taken from the fully opaque pixels of today's PNG images:
  - `background=#1a1b26`;
  - `foreground=#c0caf5` (lock, bullet, frame);
  - `accent=#a8cd76` (logo);
  - `failed=#f7768e`.
- **Pins:** nixarchy main pins Omarchy v4.5.0, and edge pins quattro. Their `Main.qml` is identical today. Build
  both:
  - main: `nix build .#omarchy`;
  - edge: a scratch worktree of `origin/edge` with `origin/main` and this branch merged in.
- **New sections in `pkgs/AGENTS.md`:** never at the end of the file, because edge appends its own (#1926). Put them
  after a section that main and edge share.
- **`modules/nixos.nix` already defines these, so extend them in the file's own style, never by redefining:**
  - `systemd.services`: line 1926, with a `// lib.optionalAttrs` at 1964;
  - `systemd.tmpfiles.rules`: line 1973;
  - `users.users`: line 2213.

  nixarchy packages come from the extended `pkgs` at line 1595, not the module's incoming `pkgs`.
- **This repo:**
  - p510 is never built or deployed without the owner's OK;
  - announce on `#agents:freundcloud.org.uk` before any deploy or VM check on p620, then run with
    `AGENT_BUS_ANNOUNCED=1`;
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
   - **`theme.conf`:** `[General]` with the four default colours above, and `wallpaper=` empty.
   - **`Main.qml`:**
     - **`function pick(key, fallback)`:** return `config[key]` when it is a string matching
       `/^#[0-9a-fA-F]{6}$/`, else `fallback`. Add the readonly properties `bg`, `fg`, `accent` and `failedTint`
       from it.
     - **Wallpaper:**
       - `readonly property string wallpaperPath`: when `config.wallpaper` matches
         `/^gen-[0-9]+\/background\.png$/`, it is `"file:///var/lib/nixarchy-greeter/out/" + config.wallpaper`;
         otherwise `""`.
       - The root `color: root.bg`.
       - First child: `Image { anchors.fill: parent; source: root.wallpaperPath; asynchronous: true; fillMode:
         Image.PreserveAspectCrop; sourceSize.width: root.width; sourceSize.height: root.height; visible: status
         === Image.Ready }`.
     - **Panel:** a `Rectangle` that is a **sibling before** the `Column`, not its parent. It is centred, sized to
       the `Column` plus 48 px, with `color: Qt.alpha(root.bg, 0.75)` (no `opacity`, which children would
       inherit) and `radius: 8`.
     - **Tinted slots:** logo, lock and frame each become an `Item` slot with an explicit size:
       - logo: `width: Math.min(800, root.width * 0.8)` and `height: Math.round(width * 185 / 800)`, since
         `logo.png` is 800×185;
       - lock: 34×38;
       - frame: 286×48.

       Each slot holds two children:
       - `Loader { id: <x>L; anchors.fill: parent; source: "Tinted.qml"; visible: status === Loader.Ready }`,
         with `Binding { target: <x>L.item; when: <x>L.status === Loader.Ready; property: "tint"; value: ... }`
         and the same for `src`. The tint for the lock and frame is `root.loginFailed ? root.failedTint :
         root.fg`; for the logo it is `root.accent`. Bindings, not assignments in `onLoaded`, so the tint
         follows `loginFailed`.
       - The fallback: `Image { anchors.fill: parent; source: <today's source, including the *-failed.png
         switch>; fillMode: Image.PreserveAspectFit; visible: <x>L.status === Loader.Error }`.

       The password `Item` (lines 58–60) takes the frame slot's explicit 286×48, not `entry.width`.
     - **Bullets:** the `Repeater` delegate becomes `Rectangle { width: 7; height: 7; radius: 3.5; color:
       root.fg }`.
     - **Failed state:** in `onLoginFailed`, set `password.text = ""` first, then `root.loginFailed = true`.
       Delete `onTextChanged: root.loginFailed = false`. In `Keys.onPressed`, for Return and Enter keep today's
       login call and `event.accepted = true`. For any other key, set `root.loginFailed = false` and leave
       `event.accepted` false, so the `TextInput` still gets the character.
   - **`Tinted.qml`:**

     ```qml
     import QtQuick
     import QtQuick.Effects
     Item {
       property url src
       property color tint
       Image { id: shape; anchors.fill: parent; source: parent.src; fillMode: Image.PreserveAspectFit;
               visible: false; layer.enabled: true }
       Rectangle { id: fill; anchors.fill: parent; color: parent.tint; visible: false }
       MultiEffect { anchors.fill: parent; source: fill; maskEnabled: true; maskSource: shape }
     }
     ```

   - **`postInstall`:**

     ```bash
     # Why: pkgs/AGENTS.md#the-greeter-follows-the-omarchy-theme-N
     patch -d "$out/share/sddm/themes/omarchy" -p1 --forward --fuzz=0 < ${./N-greeter-theme.patch}
     install -m644 ${./greeter/Tinted.qml} "$out/share/sddm/themes/omarchy/Tinted.qml"
     ln -s /var/lib/nixarchy-greeter/out/current/theme.conf "$out/share/sddm/themes/omarchy/theme.conf.user"
     ```

   - Add the `pkgs/AGENTS.md` section that the pointer names, after a shared section.

   → **Verify:**
   - `nix build .#omarchy` passes, and the tree has the symlink, `Tinted.qml` and the patched files;
   - `checks.install-phase-budget` passes, with `installPhase` unchanged;
   - both pass again in the scratch edge worktree;
   - QML behaviour is proven in step 4.

   **Traps:** `--fuzz=0 --forward`; don't touch `installPhase`; `Main.qml` loads `Tinted.qml` only by URL.

2. **The publisher and the NixOS module** (codex).
   - **`pkgs/nixarchy-greeter-publish/`:** a Python 3 script on the stdlib, with ImageMagick on its `PATH`,
     exposed in nixarchy's `packages` and overlay. It reads `NIXARCHY_GREETER_DIR` (default
     `/var/lib/nixarchy-greeter`) and `NIXARCHY_GREETER_UID`, the user's uid, set by the unit. It does this:
     1. **Snapshot the trigger.** Read `inbox/ready` (the sync's nonce) safely, as in step 2 below; a missing
        file means no nonce.
     2. **Open the inputs.** For `inbox/colors.toml` and `inbox/background`:
        - `os.open(path, O_RDONLY|O_NOFOLLOW|O_NONBLOCK|O_CLOEXEC)`. `ENOENT` means absent, and the file is
          left out.
        - Any other error, including `ELOOP` for a symlink, is unsafe: abort.
        - `fstat` must show `S_ISREG`, `st_uid == NIXARCHY_GREETER_UID`, and a size of at most 64 KiB or
          50 MiB respectively. Otherwise abort.
        - Read at most that many bytes from the open descriptor.
     3. **Parse the colours.** `tomllib.loads`; a parse error aborts. Keep `background`, `foreground` and
        `accent`, plus `red` stored as `failed`, only when the value is a `str` matching `^#[0-9a-fA-F]{6}$`.
        Missing or bad keys are left out (content).
     4. **Start the generation.** Create `out/gen-<time_ns>/` (mode 0755).
     5. **Re-encode the image,** if present, writing into the generation directory (not `/tmp`):

        ```bash
        magick -limit memory 256MiB -limit map 512MiB -limit disk 256MiB -limit width 16KP -limit height 16KP \
          -limit time 30 '-[0]' -auto-orient -resize '3840x2160>' -strip png:<gen>/background.png
        ```

        Feed the bytes on stdin, with `subprocess` `timeout=60`. `[0]` takes the first frame of a GIF or WebP. A
        non-zero exit, a timeout or a missing output removes any partial file and leaves the image out
        (content).
     6. **Write `theme.conf`:** `[General]`, the kept keys, and `wallpaper=gen-<time_ns>/background.png` when the
        image exists. Write it as `.theme.conf.tmp` in the generation, then rename it. Every file is mode 0644.
     7. **Swap.** `os.unlink(out/.current-new)`, ignoring `ENOENT`. Then
        `os.symlink("gen-<time_ns>", out/.current-new)` and `os.replace(out/.current-new, out/current)`.
     8. **Clean up.** Remove every `gen-*` except the new one and the one `current` pointed to before.
     9. **Catch up.** Re-read the nonce. If it changed while publishing, run again from step 1, at most 3 times.
        This replaces a trigger the path unit drops while the service is still active.
     10. **Exit status.** Exit 0 on every handled outcome. An abort logs why and leaves `current` untouched.
   - **`modules/nixos.nix`:**
     - **The option:** `greeterThemeUser`, inserted after `browserThemeUser` ends (line 518) and before
       `flatpaks` (line 520). It has `browserThemeUser`'s type and default, and a description that says:
       - other users see this user's wallpaper and colours at login;
       - it needs `displayManager`.
     - **Config,** with `on = cfg.displayManager && cfg.greeterThemeUser != null`, extending the existing
       attributes in place:
       - `users.users.nixarchy-greeter = { isSystemUser = true; group = "nixarchy-greeter"; }`, and
         `users.groups.nixarchy-greeter = { }`.
       - Tmpfiles rules when `on`:

         ```text
         d /var/lib/nixarchy-greeter 0755 root root -
         d /var/lib/nixarchy-greeter/inbox 0755 <user> users -
         d /var/lib/nixarchy-greeter/out 0755 nixarchy-greeter nixarchy-greeter -
         ```

         When not on: `R /var/lib/nixarchy-greeter`.
       - `environment.systemPackages = [ nixarchy-greeter-sync ]` when `on`, so `omarchy-refresh-sddm` finds
         it.
       - `systemd.paths.nixarchy-greeter-publish`: `wantedBy = [ "paths.target" ]`, and
         `pathConfig.PathChanged = "/var/lib/nixarchy-greeter/inbox/ready"`. The sync renames `ready` into
         place, which is an `IN_MOVED_TO`.
       - `systemd.services.nixarchy-greeter-publish`:
         - `wantedBy = [ "multi-user.target" ]`;
         - `after = [ "systemd-tmpfiles-setup.service" "systemd-tmpfiles-resetup.service" ]`;
         - `environment.NIXARCHY_GREETER_UID` set to `toString config.users.users.<user>.uid`, when that uid is
           set. Otherwise the script resolves the name with `pwd.getpwnam` from `NIXARCHY_GREETER_USER`.

           Either way the value changes the unit, so a switch to another user restarts and republishes it. The
           old user's files then fail the owner check, and the greeter falls back to the defaults.
         - `serviceConfig`:

           ```nix
           {
             Type = "oneshot";
             User = "nixarchy-greeter";
             Group = "nixarchy-greeter";
             ExecStart = "${pkg}/bin/nixarchy-greeter-publish";
             TimeoutStartSec = 120;
             ProtectSystem = "strict";
             ProtectHome = true;
             NoNewPrivileges = true;
             PrivateTmp = true;
             PrivateNetwork = true;
             PrivateDevices = true;
             ReadWritePaths = [ "/var/lib/nixarchy-greeter/out" ];
             MemoryMax = "1G";
             RestrictAddressFamilies = "none";
             LockPersonality = true;
             ProtectKernelTunables = true;
             ProtectKernelModules = true;
             ProtectKernelLogs = true;
             ProtectControlGroups = true;
             RestrictNamespaces = true;
             RestrictSUIDSGID = true;
             SystemCallArchitectures = "native";
           }
           ```

           `MemoryDenyWriteExecute` is left off on purpose: ImageMagick's coders and OpenMP can need it.
           `RuntimeMaxSec` does not bound a oneshot start; `TimeoutStartSec` does.

   → **Verify:**
   - `nix build .#nixarchy-greeter-publish`;
   - a `nix eval` of a test configuration with the option on and off shows the units and rules, or the `R` rule;
   - step 5's tests.

   **Trap:** a static user, not `DynamicUser`, because the greeter must traverse into `out/`.

3. **The sync, the hooks and the refresh command** (coder).
   - **`pkgs/nixarchy-greeter-sync/`:** a `writeShellApplication` with `coreutils` and `util-linux` in
     `runtimeInputs`, exposed in `packages` and the overlay. It does this:
     1. `dir=${NIXARCHY_GREETER_DIR:-/var/lib/nixarchy-greeter}` and `inbox=$dir/inbox`. If
        `[ -d "$inbox" ] && [ -w "$inbox" ]` fails, exit 0.
     2. `[ -n "${XDG_RUNTIME_DIR:-}" ] || exit 0`, then `exec 9>"$XDG_RUNTIME_DIR/nixarchy-greeter-sync.lock"` and
        `flock 9`.
     3. `trap 'rm -f "$inbox"/.tmp.*' EXIT`.
     4. `src=$HOME/.local/state/omarchy/current/theme/colors.toml`. If it is a regular file, run
        `install -m 0644 -- "$src" "$inbox/.tmp.colors"`, then `mv -f` it to `colors.toml`. Otherwise
        `rm -f "$inbox/colors.toml"`.
     5. `bg=$(readlink -f -- "$HOME/.local/state/omarchy/current/background" 2>/dev/null || true)`. If `bg` is a
        regular file whose extension, in lower case, is png, jpg, jpeg, gif, bmp or webp, copy it with
        `install -m 0644` the same way to `background`. Otherwise `rm -f "$inbox/background"`.
     6. Run `date +%s%N > "$inbox/.tmp.ready"`, `chmod 0644`, then `mv -f "$inbox/.tmp.ready" "$inbox/ready"`.
        A rename works even when an old `ready` belongs to someone else, because the user owns the directory.
   - **`modules/home.nix`,** next to the `"omarchy/hooks/theme-set.d/cursor"` entry (line 1570). Add two
     executable files, `"omarchy/hooks/theme-set.d/20-greeter"` and `"omarchy/hooks/post-boot.d/20-greeter"`,
     each with:

     ```bash
     #!/usr/bin/env bash
     exec ${pkgs.nixarchy-greeter-sync}/bin/nixarchy-greeter-sync
     ```

     Use the package the way that file already reaches nixarchy packages. They are always installed; the script
     exits 0 when the feature is off.
   - **`pkgs/omarchy/nix-bin/omarchy-refresh-sddm`:** replace the message.
     1. If `systemctl cat nixarchy-greeter-publish.path` fails, or `nixarchy-greeter-sync` is not on `PATH`, say
        the option is off and name `programs.nixarchy.greeterThemeUser`. Exit 0.
     2. Read `before=$(readlink /var/lib/nixarchy-greeter/out/current || true)` **before** the sync. Run
        `nixarchy-greeter-sync`, then read the nonce it wrote from `inbox/ready`.
     3. Wait up to 15 s for `out/current` to differ from `before`, and for the publisher to be inactive.
     4. Report "the next login screen uses THEME" or "not published (see `journalctl -u
        nixarchy-greeter-publish`)".

   → **Verify:** `nix build` of both packages, `shellcheck` clean, and step 5's tests.

4. **The VM check** (agy): new `tests/greeter-theme.nix`, registered in `flake.nix` next to `session` (line
   2054), with the same arguments.
   - **Pattern:** it follows `tests/session.nix`'s greeter section (lines 558–600).
   - **Nodes:**
     - `machine`: `programs.nixarchy.greeterThemeUser` is the test user, and SDDM's compositor is Hyprland,
       spelled out as in nixos_config's `hosts/common/nixos/omarchy-sddm.nix`:

       ```nix
       services.displayManager.sddm.wayland.compositorCommand =
         "${hyprland}/bin/Hyprland --config ${omarchy}/share/omarchy/default/sddm/hyprland.lua";
       ```

     - `broken`: the same, but with `programs.nixarchy.package` overridden so that `Tinted.qml` holds a syntax
       error. The store is read-only in a running VM, so this needs its own node.
   - **Pixels:** read with `${pkgs.imagemagick}/bin/magick <png> -format '%[pixel:p{x,y}]' info:` through
     `subprocess`, as `tests/session.nix` does near line 2698. No Pillow.
   - **Per case:**
     - record `journalctl -u display-manager --show-cursor -n0` first;
     - `systemctl restart display-manager`;
     - wait for the greeter seat;
     - screenshot and check the pixels;
     - type the password;
     - assert a new `Authentication for user ... successful` after that cursor, and a new user session in
       `loginctl`;
     - log out with `loginctl terminate-user`.
   - **Publishing:** write files into the inbox as the test user, then run the sync's step 6 (a new `ready`). Wait
     until the service is inactive and `out/current` has changed, or is unchanged for the abort cases.
   - **Pixel spots:** sample a corner well outside the form for the background or wallpaper, and pixel spots
     inside the logo, the lock and the frame border. Never sample the blended panel.
   - **Cases on `machine`:**
     1. **No theme data:** the corner is `#1a1b26`, the lock `#c0caf5` and the logo `#a8cd76`, all within a
        tolerance of 8 per channel.
     2. **Theme:** `background = "#ff0000"`, `foreground = "#00ff00"`, `accent = "#ffff00"` and
        `red = "#ff00ff"`, plus a 64×64 blue PNG. The corner is blue (the wallpaper fills the screen), the lock
        green and the logo yellow.
     3. **Wrong password,** with case 2's theme: after the field clears, the lock is `#ff00ff`. After one more key
        it is green again.
     4. **Bad colour:** `background = "red;"` and no image. The corner is `#1a1b26` and login works (content:
        published without the key).
     5. **Symlink:** `colors.toml` is a symlink to `/etc/shadow`. `current` is unchanged (abort), and login works.
     6. **FIFO:** `background` is a FIFO. The service finishes within `TimeoutStartSec`, `current` is unchanged,
        and login works.
     7. **Oversized:** `background` is a 60 MiB file. `current` is unchanged, and login works.
   - **Case on `broken`:** today's PNG images show (lock `#c0caf5` at the lock spot), and login works.

   → **Verify:** `nix build .#checks.x86_64-linux.greeter-theme -L` passes on p620. nixarchy's VM checks run
   there, so announce on the bus first.

   **Trap:** keep it off the cheap-checks list. It is a VM check, like `session`.

5. **Script tests** (coder). Both set `NIXARCHY_GREETER_DIR` to a temporary tree.
   - **`tests/greeter-sync.nix`:** a `runCommand` with a fake `$HOME` and `XDG_RUNTIME_DIR`. It covers:
     - a valid theme;
     - a missing `colors.toml`;
     - a video background (the inbox image is removed);
     - an uppercase `.PNG`;
     - `ready` replaced when an old one is read-only;
     - two runs started together, where the final inbox matches the last one;
     - a missing inbox and a read-only inbox (exit 0, nothing written).
   - **`tests/greeter-publish.nix`:** `NIXARCHY_GREETER_UID` is the build user's uid. It covers:
     - **Content:** valid input; bad hex; a non-string value; a missing file; a corrupt image. Each publishes,
       without the bad part.
     - **Unsafe:** a symlink, a FIFO, an oversized file and a TOML parse error. Each aborts with `current`
       unchanged.
     - A valid JPEG comes out as PNG at most 3840×2160.
     - A 3-frame GIF gives one PNG.
     - Only two generations are kept.
     - A leftover `.current-new` doesn't block the next publish.
     - A nonce change during a run triggers the catch-up.

     The owner-mismatch case needs a second uid, so it is covered in the VM check (case 5's file belongs to
     root).
   - Register both among the cheap checks in `flake.nix`.

   → **Verify:** both pass with `nix build .#checks.x86_64-linux.<name>`.

6. **nixarchy PR and edge** (lead).
   - Review the diff against steps 1–5, and run the Codex and agy reviews.
   - Open the PR: "Closes N". Merge it when CI is green.
   - Dispatch `omarchy-edge` after the bus announcement, and confirm edge contains the merge commit. Merged on
     main does not mean published to edge.

7. **This repo** (lead), in this worktree after edge publishes:
   - `nix flake update nixarchy`.
   - Add `programs.nixarchy.greeterThemeUser = "olafkfreund";` to `hosts/p620/nixos/nixarchy.nix`,
     `hosts/razer/nixos/nixarchy.nix` and `hosts/p510/nixos/nixarchy.nix`, next to the other
     `programs.nixarchy` settings.
   - `just check-syntax`, `just test-host p620` and `just test-host razer`.
   - Open the PR, linking intent, spec and plan, and merge it.

8. **Deploy and check** (lead):
   - razer first, with `just deploy-via-p620 razer`, then p620 with `just p620`. Bus announcement before each.
   - On each host:
     - `systemctl status nixarchy-greeter-publish.path` is active;
     - `omarchy theme set` to a light theme, then `omarchy-refresh-sddm` reports the theme;
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
| `checks.greeter-theme` (VM, p620) | 7 cases on `machine` plus `broken` pass |
| `just test-host p620`, `just test-host razer` | pass |
| razer and p620 greeter, light and dark theme | theme shown, login works |

## Rollback

- **This repo:** set `greeterThemeUser = null` on a host. Its next switch removes `/var/lib/nixarchy-greeter`
  (the tmpfiles `R` rule), and the greeter goes back to today's look. Or revert the step-7 PR, which also restores
  the previous pin. With the option gone, the theme has no `theme.conf.user` symlink, so leftover data is
  harmless. Remove it by hand if wanted:

  ```bash
  sudo rm -rf /var/lib/nixarchy-greeter
  ```

- **A greeter that will not start:** choose the previous generation at boot, then revert.
- **nixarchy:** revert the PR. The option goes away, and the theme goes back to upstream's files.
