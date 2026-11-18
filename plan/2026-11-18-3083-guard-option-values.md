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
  the branch's, except the two approved dry runs (cases 21 and 22).

## Steps

1. **`modules/programs/claude-guard-prepare.sh`**:
   - Add a first `awk` pass before the `sed` split (`RS = "^$"`, gawk). It walks the command one character at a
     time and tracks quote state: none, single, `$'…'` (a `'` right after `$`), or double.
     - **Inside quotes:** `;`, `&`, `|` and newline become spaces. In double quotes and `$'…'`, a backslash
       escapes the next character.
     - **Outside quotes:** a backslash followed by `;`, `&`, `|` or newline keeps the backslash, and the separator
       after it becomes a space. The backslash must stay: the plain-character allow-list then keeps the segment.
       The suites' `#3047 review 3: backslash in a dry-run line` case needs this.
   - In the word walk, also strip trailing whitespace, not only leading:
     `sub(/^[[:space:]]+/, "", line); sub(/[[:space:]]+$/, "", line)`. Otherwise `just test-host p510` counts an
     empty last field as an argument.
   - In the word walk, before the `-f`/`-d` test, add:
     `if ((word ~ /^--[a-z-]+=/ && word !~ /^--command=/) || word ~ /^-[fdEF]./) continue`.
   - Add the safe-recipe drop. After the `NAME=value` skip, when `words[i] == "just"` and `words[i+1]` is in the
     table, drop the segment if `count - (i + 1) <= max` and no remaining word starts with `-`.
     - Keep it inside the existing plain-character `if`.
     - Put the table at the top of that awk program, with a comment stating the rule for being on the list.

   A working prototype of the quote pass and the attached-value skip passes every case below and the comparison in
   step 5. It is at
   `/tmp/claude-1000/-home-olafkfreund--config-nixos/ee8128ca-3f78-4bb7-893d-460e9ec96134/scratchpad/proto3083/prepare.sh`,
   but may have been cleared; the description above is complete without it.

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

3. **Tests.** Every guard-suite case is added in base64, as the files already do, so the harness doesn't trip the
   live hook. The p510 suite runs each case in both contexts, off p510 and on p510. In the bus suite the same
   commands are used as written: the bus guard blocks `just p510` as well.

   **Cases**, with the expected exit in every context (bus, p510-off, p510-on):

   | # | Command | Exit |
   | --- | --- | --- |
   | 1 | `just --shell-arg 0 p510` | 2 |
   | 2 | `just --set A B p510` | 2 |
   | 3 | `just -f "a b" p510` | 2 |
   | 4 | `just check-syntax p510` | 2 |
   | 5 | `just mod::p510` | 2 |
   | 6 | `just ../p510` | 2 |
   | 7 | `just --command=sudo -n just p510` | 2 |
   | 8 | `just test-host p620 p510` | 2 |
   | 9 | `just --list-heading 'a&b' p510` | 2 |
   | 10 | `just --list-heading 'a;b' p510` | 2 |
   | 11 | `just --list-heading "a\|b" p510` (a literal `\|` inside double quotes) | 2 |
   | 12 | `just --list-heading a\;b p510` | 2 |
   | 13 | `just --list-heading $'a\';b' p510` | 2 |
   | 14 | `just --list-heading 'a` newline `b' p510` | 2 |
   | 15 | `just --shell-arg=0 p510` (already blocked; regression) | 2 |
   | 16 | `just -fFILE p510` (already blocked; regression) | 2 |
   | 17 | `just -- p510` (already blocked; regression) | 2 |
   | 18 | `just test-host p510` | 0 |
   | 19 | `just test-host p510` (trailing space) | 0 |
   | 20 | `just -n p510` | 0 |
   | 21 | `just --color=always -n p510` | 0 |
   | 22 | `just -fFILE -n p510` | 0 |
   | 23 | `just check-syntax ; ssh p510 uptime` | 0 |
   | 24 | `just --shell-arg -n p510` | 2 |

   - **`modules/programs/claude-guard-prepare.test.sh`:**
     - change the `ssh $host 'cd /etc/nixos && $verb'` expectation to `ssh $host cd /etc/nixos    $verb`, because
       the `&&` is inside quotes;
     - add the prepare output for cases 9 to 14, where the separator becomes a space and the segment is not split;
     - add the dropped shapes: cases 18 to 22, and each of the ten safe recipes at its maximum argument count;
     - add near misses that must be kept: one argument too many (case 8), an argument starting with `-`
       (`just test-host -x`), an option before the recipe (`just -q test-host p510`), case 24, and case 7.
   - **`scripts/test-bus-guard.py` and `scripts/test-p510-deploy-guard.py`:** cases 1 to 24.
   - **Arity check:** a new `scripts/test-guard-safe-recipes.sh`, added to the `test-guards` recipe in the
     `Justfile`. It reads `just --dump --dump-format json` and the table from `claude-guard-prepare.sh`. It fails
     if a listed recipe is missing, or if its parameter count differs from the table's max.

   **Verify:** `just test-guards` passes.

   **Traps:**
   - Never put a deploy-shaped command in plain text on a command line: the live guard reads command text. Use
     base64 in the suites, and files for anything else.
   - The arity script must not run any recipe; `--dump` only parses.

4. **`Justfile`:** above each of the ten listed recipes, add
   `# Deploy guards drop this as non-disruptive (claude-guard-prepare.sh, #3083).`

   **Verify:** `just --list` still lists them, and `just test-guards` passes.

   **Traps:** none.

5. **Lead: compare, build, review, PR.**
   - Commit `scripts/compare-guards.py`. It takes `MAIN_NIX MAIN_PREPARE BRANCH_NIX BRANCH_PREPARE`, runs from the
     branch checkout, and prints every suite command where the branch's guard exits lower than main's, in each of
     the three contexts.
   - Create the main side with `git show origin/main:modules/programs/claude-code-managed.nix > <tmp>/main.nix`, and
     the same for `claude-guard-prepare.sh`.
   - Run it with the branch's two files. Expected output: exactly the dry runs from cases 21 and 22, in all three
     contexts, and nothing else. Cases 21 and 22 are the approved exceptions from intent question 2. Any other line
     fails the step.
   - Build the p620 and razer toplevels.
   - Codex reviews the diff (`codex review --base origin/main`), with `git status --porcelain` checked before and
     after.
   - Open the PR, linking intent, spec and plan, and post `@codex review`.

6. **Lead: deploy and live probe.** After the merge, deploy p620 (local switch) and razer
   (`just deploy-via-p620 razer`), announcing on the bus first.

   Then run `scripts/probe-installed-guards.sh` in the scratchpad (not committed). It finds the installed guard
   scripts in `/etc/claude-code/managed-settings.json`, under the `command` keys matching
   `claude-(bus-announce|p510-deploy)-guard.sh`. Then it reads the cases from a file, one per line, with `<NL>` for
   a newline. It feeds each one as `{"tool_input":{"command":…}}` to each guard, using `env -u AGENT_BUS_ANNOUNCED -u
   P510_DEPLOY_APPROVED`, and prints the exit codes. Nothing is executed.
   - **Expected on p620 and razer** (off p510): cases 1 to 17 and 24 exit 2 in both guards; cases 18 to 23 exit 0.

   p510 is deployed only with the owner's OK, and is then probed the same way.

## Tests

| Command | Expected |
| --- | --- |
| `just test-guards` | passes (prepare test, both suites, arity script) |
| `shellcheck modules/programs/claude-guard-prepare.sh scripts/test-guard-safe-recipes.sh` | clean |
| `scripts/compare-guards.py` against main | only cases 21 and 22 |
| `nix build .#nixosConfigurations.{p620,razer}.config.system.build.toplevel` | builds |
| live probe | as in step 6 |

## Rollback

Revert the merge commit and redeploy p620 and razer. The guards then behave as on main today.
