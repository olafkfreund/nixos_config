---
status: approved
issue: 3083
intent: intent/2026-11-18-3083-guard-option-values.md
---

# Spec: deploy guards miss a recipe that is not the first word after just's options

## Design

The approved decision is "any word": a `just` segment is a deploy when any of its words is a deploy recipe name.
Three changes to prepare keep that from being bypassed or from blocking everyday commands:

- a separator inside quotes no longer splits a segment;
- a dry run behind an attached value is recognised;
- a non-disruptive recipe given only its own arguments is dropped.

Everything below was prototyped in a scratch copy and checked against the installed suites (2026-11-18).

### 1. The `just=` pattern (both guards)

`modules/programs/claude-code-managed.nix`, lines 372 (p510 guard) and 556 (bus guard). Both lines get the same
change:

```bash
just='(^|[^[:alnum:]_-])just([[:space:]]+[^[:space:];|&]+)*[[:space:]]+([^[:space:];|&]*(::|/))?'
```

- `([[:space:]]+[^[:space:];|&]+)*` takes any words before the recipe, not only options and `NAME=value`. That
  covers an option's value, `--set`'s two values, a quoted value whose quotes prepare deletes, and an earlier
  recipe. The words stop at `;`, `|` and `&`, so a deploy word in the next segment isn't credited to this `just`.
- `([^[:space:];|&]*(::|/))?` lets the recipe carry a module path (`mod::p510`) or a search directory (`../p510`),
  both forms just accepts.
- `(^|[^[:alnum:]_-])` before `just` stops `adjust p510` and similar words from matching. Main blocks those; they
  are not commands.

The patterns that use `$just` do not change: `$just[a-z-]*deploy`, `$just(p510|p620|razer)$end`, the #2951 list,
the p510-only recipes, and the on-p510 local list.

### 2. Prepare (`modules/programs/claude-guard-prepare.sh`)

**a. Quoted separators** (Codex review). A new first pass walks the command and tracks quote state: single quotes,
`$'…'` (where a backslash escapes), double quotes, and backslash escapes outside quotes. Inside quotes, each `;`,
`&`, `|` and newline becomes a space. Outside quotes, the same holds for one right after a backslash. The existing
split then sees only the shell's real separators.

Without this pass, `just --list-heading 'a;b' p510` splits into `just --list-heading 'a` and `b' p510`, and the
second segment has no `just`. An unterminated quote leaves the rest of the command unsplit, which is stricter.

One existing test changes: `ssh p510 'cd /etc/nixos && nhs'` now prepares to `ssh p510 cd /etc/nixos    nhs`
rather than keeping the `&&`. The deploy pattern still matches it.

**b. Dry runs behind attached values** (intent question 2). The word walk skips a word of the form `--name=value`,
except `--command=…`, and a short value-taking option with its value attached: `-fX`, `-dX`, `-EX`, `-FX`. That
lets `just --color=always -n p510` and `just -fFILE -n p510` reach `-n`.

`--command=` is excluded because a `-n` after it can belong to the command being run: `just --command=sudo -n just
p510` runs `sudo -n just p510`. Separate-value options other than `-f` and `-d` still end the walk, so
`--shell-arg -n` is not taken for a dry run. The rule that keeps a dry run when a later word starts with `-` stays.

**c. Non-disruptive recipes with their own arguments.** A segment is dropped when, after any `NAME=value` words, it
is exactly `just <recipe>` followed by at most that recipe's number of parameters, and none of those arguments
starts with `-`. This only applies within the existing allow-list of plain characters (line 18).

The list is the recipes that take a host argument, that main lets through today, and that neither activate a
generation, collect garbage, restart services nor reboot. They are not all read-only:

| Recipe | Parameters | What it changes |
| --- | --- | --- |
| `test-host`, `diff` | 1 | nothing |
| `secrets-status-host` | 1 | nothing (`systemctl status` over ssh) |
| `build-on-p620`, `_sign-drv` | 1 | builds; signs the closure (`sudo nix store sign`) |
| `dry-run`, `boot-space`, `system-diff` | 1 (optional) | nothing (`dry-activate`, reads) |
| `preview-updates` | 1 (optional) | updates and backs up `flake.lock` locally, builds |
| `update-commit` | 2 (optional) | updates the lock, commits, pushes, opens a PR; never switches |

Arity matters. just treats a word beyond the recipe's parameters as another recipe, so `just test-host p620 p510`
runs `p510`. That segment has a word too many, so it is not dropped, and the pattern blocks it. Options before the
recipe are not allowed in this shape; any segment that has them goes to the pattern.

A comment above the list says what qualifies a recipe for it. `boot-space-clean`, `cleanup`, `fix-agenix-remote`,
the deploy recipes and `update-commit-deploy` are not on it.

### 3. Tests

- **`modules/programs/claude-guard-prepare.test.sh`:**
  - cases for each quoted and escaped separator form (`'a;b'`, `"a|b"`, `'a&b'`, `a\;b`, `$'a\';b'`, and a newline
    inside quotes);
  - each dropped shape;
  - each near miss that must be kept: a word too many, an argument starting with `-`, an option before the recipe,
    `--shell-arg -n`, and `--command=sudo -n`;
  - the changed `ssh … && nhs` expectation.
- **`scripts/test-bus-guard.py` and `scripts/test-p510-deploy-guard.py`:**
  - each row of the intent's table, the five quoted or escaped forms, and `just --command=sudo -n just p510`, all of
    which must be blocked;
  - `just test-host p510`, `just -n p510`, `just --color=always -n p510` and `just check-syntax ; ssh p510 uptime`,
    which must pass;
  - every case in each context (bus guard; p510 guard off p510 and on p510).
- **Arity check** in `just test-guards`. It reads `just --dump --dump-format json` and fails if a listed recipe is
  missing or its parameter count differs. It checks arity only: whether a recipe stays non-disruptive is a review
  question, because its effects live in the scripts it calls. Feeding recipe bodies to the guard was rejected,
  because `build-on-p620`'s help text and `update-commit`'s script call trip it.
- **Comparison against main** from #3047: every suite command goes through main's guards and the branch's. The
  branch must not be more permissive anywhere. The two dry runs are not in the suites, so they don't show up here.

## Alternatives rejected

- **Parse just's arguments exactly** (option arity, quoted values, every recipe argument). The owner chose any-word
  for the intent.
- **Any word, no exemptions.** The prototype blocked `just test-host p510`, `just test-host p620` and
  `just boot-space p510`. Main allows these, and AGENTS.md requires the build test before every deploy. Blocking
  them trains everyone to add `AGENT_BUS_ANNOUNCED=1` by reflex.
- **Exempt safe recipes inside the regex** (a negative match): ERE has no lookahead, and it can't count arguments.
- **Block any segment that contains a quote and `just`.** This is simpler than a quote walk, but it would block
  every `gh … --body "…just…"` and `git commit -m` that happens to name a host.

## Risks

- **More false positives in prose.** A command whose text has `just`, a few words and a host name in one segment is
  now blocked, for example `gh pr create --title "just docs for p510"`. Prose already goes in files (AGENTS.md,
  "Claude Code").
- **The quote walk misreads shell syntax it does not model**, such as heredocs and `$(…)` inside double quotes. When
  it is wrong, it fails toward fewer splits, so a segment keeps more words and matches more. The suites and the
  comparison against main cover the known forms.
- **A listed recipe later becomes disruptive.** The arity check doesn't see that. To put it in review, each listed
  recipe in the `Justfile` gets a one-line comment: `# Deploy guards drop this as non-disruptive
  (claude-guard-prepare.sh, #3083).`
- All three hosts carry the guards. A bad pattern would block every `just`, or none. The suites and the live probe
  below cover that.

## Verification

1. `just test-guards` passes, and shellcheck is clean.
2. The comparison against main reports nothing more permissive across all suite commands.
3. The p620 and razer toplevels build.
4. After deploying p620 and razer, payloads are fed straight to the installed guards, with nothing executed:
   - the six missed forms, the five quoted or escaped forms, and the `--command=` form exit 2 in both guards;
   - `just test-host p510`, `just -n p510` and `just --color=always -n p510` exit 0.
5. p510 is deployed only with the owner's OK.
