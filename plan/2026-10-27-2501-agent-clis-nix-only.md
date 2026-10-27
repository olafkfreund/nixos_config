---
status: draft
issue: 2501
spec: spec/2026-10-27-2501-agent-clis-nix-only.md
---

# Plan: Agent CLIs are versioned only by Nix, with Omarchy account routing kept

## Decisions carried from the approved spec

- Keep Omarchy's mise `[wrappers]` and `omarchy-agent-account-exec` exactly
  as nixarchy ships them. Do not touch `/etc/mise/conf.d`.
- `codex` comes from upstream GitHub release binaries, in a new local package
  `pkgs/codex-bin`, updated by a script and the nightly autoupdate workflow.
- `overlays/custom-packages.nix` maps `codex` → `codex-bin` and
  `claude-code` → `claude-code-native`, so nixarchy's `defaultAgent` and
  microvm template use our pins. That removes the stray nixpkgs `claude-code`
  2.1.308 from p620's `system-path`. Both are leaf packages, so this is safe
  for the binary cache.
- The packaged `codex` guards `exec`: when a prompt is given as an argument,
  stdin is not a terminal and `CODEX_EXEC_STDIN` is unset, the real binary
  gets `</dev/null`. This fixes the reproduced hang (openai/codex#20919).
- `agy` stays as it is (the `antigravity-nix` input plus
  `update-antigravity.sh`). No account routing.

## Refinements found while planning (within the spec)

- **Use the `codex-package-<target>.tar.gz` asset, not the bare binary.**
  The release ships a complete package tree: `bin/codex`,
  `bin/codex-code-mode-host`, `codex-package.json`, `codex-path/rg` and
  `codex-resources/bwrap`, all static musl. This settles the spec's bubblewrap
  risk. nixpkgs instead symlinks rg/bwrap from the store and patches codex's
  daemon validation to accept the links
  (`pkgs/by-name/co/codex/nix-package-layout.patch`). With the upstream tree
  as-is there are no links, so no patch is needed.
- **The guard sits outside that tree.** nixpkgs warns that a wrapper *at*
  `bin/codex` breaks the app-server daemon's "staged-vs-running executable
  content" check. So the tree is installed untouched at
  `$out/libexec/codex/`, and `$out/bin/codex` is a script that execs
  `$out/libexec/codex/bin/codex`. Measured with 0.164.0 in the scratchpad: a
  wrapper of that shape, then `codex app-server daemon start` / `version` /
  `stop`, all succeed. (`daemon start` copies the tree into
  `$CODEX_HOME/packages/app-server-daemon/current`. Today `~/.codex/packages`
  doesn't exist, so nothing needs cleaning up.)

## Steps

1. **`pkgs/codex-bin/default.nix` (new)** — `stdenvNoCC.mkDerivation`,
   modelled on `pkgs/opencode-bin/default.nix`:
   - `version = "0.164.0"`. `src = fetchurl` of
     `https://github.com/openai/codex/releases/download/rust-v${version}/codex-package-${target}.tar.gz`,
     with `target` = `x86_64-unknown-linux-musl` / `aarch64-unknown-linux-musl`
     taken from a `sources` attrset keyed by `stdenv.hostPlatform.system`.
     Each entry carries its own hash, the same pattern as
     `pkgs/claude-code-native`. Throw on unsupported systems.
   - `sourceRoot = "."`, `dontPatchELF = true`, `dontStrip = true`,
     `dontFixup = true` (static binaries; fixup would also rewrite the tree
     that the daemon checks).
   - `installPhase`: `mkdir -p $out/libexec/codex $out/bin`,
     `cp -a bin codex-package.json codex-path codex-resources $out/libexec/codex/`,
     then write `$out/bin/codex` from `./codex-wrapper.sh` with
     `substitute … --subst-var-by real $out/libexec/codex/bin/codex` and
     `chmod +x`.
   - `doInstallCheck = true` running `./guard-test.sh` (step 2) plus
     `$out/bin/codex --version | grep -F ${version}`.
   - `meta`: `mainProgram = "codex"`, `license = lib.licenses.asl20`,
     `sourceProvenance = [ lib.sourceTypes.binaryNativeCode ]`, platforms as
     above. Header comment in the repo's style: why upstream binaries, why the
     tree is untouched (daemon check), and the update command.

   → verify: `nix build .#codex-bin` (after step 3 wires it), `ls
   result/libexec/codex/codex-resources/bwrap`, `result/bin/codex --version`
   prints `codex-cli 0.164.0`.
   Traps: hashes are SRI `sha256-…`. Get them with `nix store prefetch-file
   --json <url>`, never by hand. No `with lib;`.

2. **`pkgs/codex-bin/codex-wrapper.sh` + `pkgs/codex-bin/guard-test.sh`
   (new)** — POSIX `sh`, `#!@shell@` substituted to `${runtimeShell}`:
   - The wrapper finds the subcommand by skipping global options; for the
     value-taking ones (`-c --config --enable --disable --remote
     --remote-auth-token-env -i --image -m --model --local-provider -p
     --profile -s --sandbox -C --cd --add-dir -a --ask-for-approval`) it also
     skips the next arg, and accepts the `--opt=value` form. If the subcommand
     is `exec` or `e`, it scans the rest the same way, adding exec's
     value-taking options (`--thread-source --cyber-access-program
     --output-schema --color -o --output-last-message`). It looks for a
     positional argument that isn't `resume`, `fork`, `review` or `help`.
   - If that positional exists and isn't `-`, and `[ ! -t 0 ]`, and
     `${CODEX_EXEC_STDIN-}` is empty, it prints to stderr
     `codex: stdin is not a terminal and was not read; set CODEX_EXEC_STDIN=1 to append it (openai/codex#20919)`
     only when `[ -p /dev/stdin ] || [ -S /dev/stdin ]`, then runs
     `exec "@real@" "$@" </dev/null`. Otherwise `exec "@real@" "$@"`.
   - Add a `# shortcut:` comment in the form ponytail requires: the
     option list is copied from `codex --help` 0.164.0; update it if a new
     value-taking option appears; delete the guard when #20919 is fixed.
   - `guard-test.sh` instantiates the wrapper with `@real@` pointing at a stub
     that prints `readlink /proc/self/fd/0`, and asserts, with the stdin
     shown:

     | args | stdin | expect |
     |---|---|---|
     | `exec 'hi'` | open pipe (`sleep 5 \|`) | `/dev/null` |
     | `exec --skip-git-repo-check -m o3 'hi'` | pipe | `/dev/null` |
     | `-c a=b -p implement exec 'hi'` | pipe | `/dev/null` |
     | `e 'hi'` | pipe | `/dev/null` |
     | `exec -` | pipe | pipe (not replaced) |
     | `exec` (no prompt) | pipe | pipe |
     | `exec 'hi'` with `CODEX_EXEC_STDIN=1` | pipe | pipe |
     | `exec 'hi'` | file `< /etc/hostname` | `/dev/null` |
     | `exec -m exec` (option value only) | pipe | pipe |
     | `--version` | pipe | pipe |
     | `login status` | pipe | pipe |

     Exit non-zero on the first mismatch.

   → verify: `sh pkgs/codex-bin/guard-test.sh` passes locally and inside
   `installCheckPhase`.
   Traps: the build sandbox has no tty, which is exactly the case under
   test. Don't rely on `/dev/tty`.

3. **`overlays/custom-packages.nix:6` and `flake.nix:546–556`** — after the
   `claude-code-native` line, add:

   ```nix
   codex-bin = final.callPackage ../pkgs/codex-bin { };
   # One version of each agent CLI for every consumer, nixarchy's included (#2501).
   codex = final.codex-bin;
   claude-code = final.claude-code-native;
   ```

   In `flake.nix`'s packages set, next to `opencode-bin`:
   `codex-bin = pkgs.callPackage ./pkgs/codex-bin { };`.

   → verify:
   `nix eval --raw .#nixosConfigurations.p620.pkgs.codex.name` →
   `codex-bin-0.164.0`;
   `nix eval --raw .#nixosConfigurations.p620.pkgs.claude-code.name` →
   `claude-code-native-2.1.311` (or current). Then confirm p620's
   `system-path` has no `claude-code-2.1.308`:
   `nix path-info -r $(nix build --no-link --print-out-paths
   .#nixosConfigurations.p620.config.system.build.toplevel) | grep -E
   'claude-code-[0-9]|/[a-z0-9]{32}-codex-[0-9]'` prints nothing.
   Traps: the flake's `packages` `claude-code` entry (old npm build) is a
   different attrset, not the overlay. Leave it. Overlays on deep packages
   poison the cache, but these two are leaves, so check with `nix why-depends`
   if the closure grows unexpectedly.

4. **`home/development/codex-cli/module.nix:7–11` and
   `home/development/codex-cli.nix:39`** — comments only: `pkgs.codex` is now
   the upstream release binary via the overlay (#2501), not nixpkgs'
   build. No code change.
   → verify: `just check-syntax`.
   Traps: minimal comments (memory: strip, don't add, verbose comments).

5. **`scripts/update-codex-bin.sh` (new)** — modelled on
   `scripts/update-claude-code-native.sh`: with no args it prints the current
   version and latest; `<version>|latest` prints a Nix snippet;
   `--write latest` rewrites `version` and both hashes in
   `pkgs/codex-bin/default.nix` in place. Latest =
   `gh release view -R openai/codex --json tagName` (the `releases/latest`
   endpoint, which excludes pre-releases), stripping `rust-v`. Hashes come
   from `nix store prefetch-file --json --hash-type sha256` on both package
   tarball URLs. No `set -e`, explicit `die`, the same as the model script.
   → verify: on a scratch copy, `./scripts/update-codex-bin.sh --write
   0.163.0`, then `git diff` shows version and two hashes changed, then
   `nix build .#codex-bin` succeeds. Revert.
   Traps: `shellcheck` runs in pre-commit. `chmod +x`.

6. **`.github/workflows/package-autoupdate.yml:45`** — add to the matrix:

   ```yaml
   - pkg: codex
     script: ./scripts/update-codex-bin.sh --write latest
     paths: pkgs/codex-bin
     verify: .#codex-bin
   ```

   **`.claude/commands/update-codex.md` (new)** — short, following
   `update-claude-code.md` section A: the prerequisites, the script, build,
   guard test, `just test-host p620`, PR. Add a row to
   `docs/Nixos/COMMANDS-INDEX.md` next to `update-claude-code`.
   → verify: `actionlint` (pre-commit) passes; markdownlint passes on the
   whole files it touches (memory: pre-push lints whole files).
   Traps: docs nav — no new docs page, so `mkdocs.yml`/`mkdocs-full.yml`
   are unchanged.

7. **Build and runtime checks (no file edits)**
   - `just validate`; `just test-host p620`; razer:
     `just deploy-via-p620 razer` is a deploy, so only build:
     `just test-host razer`. p510: evaluate only (`nix eval
     .#nixosConfigurations.p510.config.system.build.toplevel.drvPath`). It
     changes too through the overlay, but it is never built or deployed
     without asking.
   - Hang regression against the built package, run once through the mise
     wrapper (`PATH=~/.local/share/mise/command-wrappers/bin:$(dirname
     result/bin/codex):…`) and once direct, under `systemd-run --user
     --wait`: `sleep 600 | codex exec --skip-git-repo-check 'reply pong'`
     prints `pong` within 60 s; `printf hi | CODEX_EXEC_STDIN=1 codex exec
     --skip-git-repo-check 'repeat the stdin block verbatim'` prints `hi`.
   - Sandbox: `codex exec --skip-git-repo-check -s workspace-write 'run ls
     and reply with the first file name' </dev/null` in a scratch dir
     completes, which proves the bundled `bwrap`.

## Tests

| Command | Expected |
|---|---|
| `nix build .#codex-bin` | builds; installCheck runs `guard-test.sh` and the version check |
| `sh pkgs/codex-bin/guard-test.sh` | all 11 cases pass |
| hang regression (step 7) | `pong` < 60 s; before the change `timeout` → 124 |
| `nix eval …p620.pkgs.{codex,claude-code}.name` | `codex-bin-*`, `claude-code-native-*` |
| closure grep (step 3) | no nixpkgs `claude-code`/`codex` paths |
| `just validate`, `just test-host p620`, `just test-host razer` | pass |
| after you deploy: `type -a claude codex` then `readlink -f` each | one store path per tool behind the mise wrapper |
| after you deploy: `omarchy agent account use codex <acct>`; `codex login status` | reports `<acct>` |

## Rollback

Revert the PR: remove the three overlay lines and the `flake.nix` entry, and
`pkgs.codex`/`pkgs.claude-code` fall back to nixpkgs. The deploy is a normal
`switch`, and a previous generation also rolls back. Nothing outside the store
changes. A codex daemon copy, if one was started, lives under
`$CODEX_HOME/packages/` and can be deleted.

## Implementation

7 steps, 9 files: per policy this goes to the `coder` agent (Sonnet), one
agent for all steps, with each step sent by `SendMessage`. Step 7's runtime
checks and the deploy announcement stay with the session model. Review is by
a fresh Opus agent given this plan and `git diff`. Deploy to p620/razer is a
separate ask after the PR is merged.
