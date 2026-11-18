---
status: draft
issue: 3083
spec: spec/2026-11-18-3083-guard-option-values.md
coders:
  1: codex   # small, tricky awk (quote walk, two drop rules); a working prototype exists to start from
  2: codex   # one regex, two places; same reviewer context as step 1
  3: codex   # the coder guard blocked edits naming the guard files' callers in #3047, and it never started that step
  4: coder   # ten one-line comments in the Justfile, mechanical
reviewers:
  - codex    # read-only review of the diff against this plan; agy is out of use (#2748)
---

# Plan: deploy guards miss a recipe that is not the first word after just's options

Self-contained: the approved decisions from the intent and spec, then the steps. Branch
`fix/3083-guard-option-values`, worktree `~/.config/nixos-3083`.

## Approved decisions

- **Any word** (intent): a `just` segment is a deploy when any word in it is a deploy recipe name. A module path
  (`mod::`) or a search directory (`../`) may come before the name.
- **Dry runs behind attached values** are allowed (intent question 2). `--command=` doesn't count as an attached
  value, because a `-n` after it can belong to the command being run.
- **Quoted separators** (`;`, `&`, `|`, newline inside quotes, or after a backslash) don't split a segment.
- **Ten non-disruptive recipes** are dropped when the segment is exactly `just <recipe>` plus at most its parameter
  count of arguments, none starting with `-`. Leading `NAME=value` words are allowed; options are not.

  | Recipe | Max args |
  | --- | --- |
  | `test-host`, `diff`, `secrets-status-host`, `build-on-p620`, `_sign-drv` | 1 |
  | `dry-run`, `boot-space`, `system-diff`, `preview-updates` | 1 |
  | `update-commit` | 2 |

  The rule for being on the list: the recipe takes a host argument, main lets it through today, and it neither
  activates a generation, collects garbage, restarts a service nor reboots. The recipes are not all read-only.
- **No command becomes less strict than main**, checked by running every suite command through main's guards and
  the branch's.

## Steps

1. **`modules/programs/claude-guard-prepare.sh`**:
   - Add a first `awk` pass before the `sed` split (`RS = "^$"`, gawk). It walks the command one character at a time
     and tracks quote state: none, single, `$'…'`, double. Inside quotes, `;`, `&`, `|` and newline become spaces;
     outside quotes, so does a backslash followed by one of them.
   - In the word walk, before the `-f`/`-d` test, add:
     `if ((word ~ /^--[a-z-]+=/ && word !~ /^--command=/) || word ~ /^-[fdEF]./) continue`.
   - Add the safe-recipe drop: after the `NAME=value` skip, if `words[i] == "just"` and `words[i+1]` is in the
     table, drop the segment when `count - (i + 1) <= max` and no remaining word starts with `-`. Keep it inside
     the existing plain-character `if`. Put the table at the top of that awk program, with a comment stating the
     rule for being on the list.

   A working prototype of the first two parts is at
   `/tmp/claude-1000/-home-olafkfreund--config-nixos/ee8128ca-3f78-4bb7-893d-460e9ec96134/scratchpad/proto3083/prepare.sh`.
   It may have been cleared; the description above is complete without it.

   **Verify:** `bash modules/programs/claude-guard-prepare.test.sh` passes after step 3's test changes, and
   `shellcheck modules/programs/claude-guard-prepare.sh` is clean.

   **Traps:**
   - Splitting must happen only at the shell's real separators.
   - An unterminated quote leaves the rest of the command unsplit, which is the stricter way to fail.
   - Keep `set -o pipefail`: the guards fail closed when prepare fails.

2. **`modules/programs/claude-code-managed.nix`**, the two `just=` lines (about 372 and 556): replace each with

   ```bash
   just='(^|[^[:alnum:]_-])just([[:space:]]+[^[:space:];|&]+)*[[:space:]]+([^[:space:];|&]*(::|/))?'
   ```

   Update the comment above each line to say any word before the recipe is skipped (#3083).

   **Verify:** both Python suites pass (`just test-guards`).

   **Traps:**
   - This is a Nix `''` string: `''` and `${` need escaping, and none appear here.
   - The patterns that build on `$just` stay as they are.

3. **Tests:**
   - **`modules/programs/claude-guard-prepare.test.sh`:**
     - change the `ssh $host 'cd /etc/nixos && $verb'` expectation to
       `ssh $host cd /etc/nixos    $verb` (the `&&` is inside quotes);
     - add cases for `'a;b'`, `"a|b"`, `'a&b'`, `a\;b`, `$'a\';b'`, and a newline inside quotes;
     - add each dropped shape: `just -n …` behind `--color=always` and `-fFILE`, and each safe recipe at its
       maximum argument count;
     - add each near miss that must be kept: one argument too many, an argument starting with `-`, an option before
       the recipe, `--shell-arg -n`, and `--command=sudo -n`.
   - **`scripts/test-bus-guard.py` and `scripts/test-p510-deploy-guard.py`:** add base64 cases, as the files already
     do, so the harness doesn't trip the live hook.
     - Blocked (exit 2): `just --shell-arg 0 p510`, `just --set A B p510`, `just -f "a b" p510`,
       `just check-syntax p510`, `just mod::p510`, `just ../p510`, `just --command=sudo -n just p510`,
       `just test-host p620 p510`, and the five quoted or escaped `--list-heading … p510` forms.
     - Allowed (exit 0): `just test-host p510`, `just -n p510`, `just --color=always -n p510`,
       `just -fFILE -n p510`, and `just check-syntax ; ssh p510 uptime`.
     - The p510 suite covers both contexts, off p510 and on p510. In the bus suite, use `p620` or `razer` where a
       host is needed.
   - **Arity check:** a new `scripts/test-guard-safe-recipes.sh`. It reads `just --dump --dump-format json` and
     the table from `claude-guard-prepare.sh`, and fails if a listed recipe is missing or its parameter count
     differs from its max. Add it to the `test-guards` recipe in the `Justfile`.

   **Verify:** `just test-guards` passes.

   **Traps:**
   - Never put a deploy-shaped command in plain text in a command line; use base64 in the suites. The live guard
     reads command text.
   - The arity script must not run any recipe.

4. **`Justfile`:** above each of the ten listed recipes, add
   `# Deploy guards drop this as non-disruptive (claude-guard-prepare.sh, #3083).`

   **Verify:** `just --list` still lists them, and `just test-guards` passes.

   **Traps:** none.

5. **Lead: compare, build, review, PR.**
   - Run the comparison against main: every suite command through main's and the branch's guards. It must report
     nothing more permissive.
   - Build the p620 and razer toplevels.
   - Codex reviews the diff (`codex review --base origin/main`), with `git status --porcelain` checked before and
     after.
   - Open the PR, linking intent, spec and plan, and post `@codex review`.

6. **Lead: deploy and live probe.** After the merge, deploy p620 (local switch) and razer
   (`just deploy-via-p620 razer`), announcing on the bus first. Then feed payloads to the installed guards, with
   nothing executed:
   - every blocked case above must exit 2 in both guards;
   - `just test-host p510`, `just -n p510` and `just --color=always -n p510` must exit 0.

   p510 is deployed only with the owner's OK.

## Tests

| Command | Expected |
| --- | --- |
| `just test-guards` | passes (prepare test, both suites, arity script) |
| `shellcheck modules/programs/claude-guard-prepare.sh scripts/test-guard-safe-recipes.sh` | clean |
| comparison against main | no command more permissive |
| `nix build .#nixosConfigurations.{p620,razer}.config.system.build.toplevel` | builds |

## Rollback

Revert the merge commit and redeploy p620 and razer. The guards then behave as on main today.
