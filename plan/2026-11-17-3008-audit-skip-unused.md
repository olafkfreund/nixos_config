---
status: draft
issue: 3008
spec: spec/2026-11-17-3008-audit-skip-unused.md
coders:
  1: codex # small tricky shell: fixture mode, inventory, resolver batch and the fail-closed skip rule
  2: codex # shell test with fixtures that must assert the fail-closed cases exactly
  3: coder # one Justfile line
reviewers:
  - codex # independent read of the script and test against this plan
  # agy: out of use by owner decision (#2748)
---

# Plan: nightly audit skips upstream issues for packages no host runs

Branch `chore/3008-audit-skip-unused`, worktree `~/.config/nixos-3008`. The workflow file
`.github/workflows/nixos-issue-audit.yml` does not change. Only `scripts/nixos-issue-audit.sh` changes, plus a new
fixture test and one `Justfile` line.

## Approved decisions (from the spec)

- One new rule in `classify_one`, fed by one inventory built per run. It only ever turns a default-Watch candidate
  into GREEN. Every failure path (timeout, error, short inventory, empty resolver output) leaves Watch.
- Rule placement: a new `elif` directly before the final `else` of `classify_one`, after every existing rule.
  Existing rules keep order and behaviour (`host_eval_bool` is not repaired here; file a separate issue). The
  hand-kept GREEN package list stays.
- Inventory: for each of p620, razer, p510,
  `nix eval --raw .#nixosConfigurations.<host>.config.system.build.toplevel.drvPath` then `nix-store -qR <drv>`;
  strip store hash and `.drv`; union of names. Evaluation only, nothing built, p510 never built.
  Each host runs under `timeout 240`. A timeout, an error, or fewer than 1000 lines for any host marks the whole
  inventory incomplete (all skips off). All inventory and resolver work shares one 600 s budget.
- Eval-only inputs: the root input names of `flake.lock` form `eval-inputs.txt`, kept apart from the inventory. A
  candidate is not dismissed if its lower-case token or family equals, or is a prefix of or prefixed by, an entry. Any
  doubt keeps Watch.
- Identity: token is the title with a leading `nixos/` dropped, then the text before the first `:`, else the first
  word (fallback only when the title has no `:` and the word is not on the module list). Token must match
  `^[A-Za-z0-9_.+-]+$`. Module or subsystem tokens (`home-manager`, `nixos`, `nix`, `systemd`, `treewide`, `modules`,
  `services`, `programs`) are never resolved and stay Watch.
- Resolver: one batched `nix eval .#nixosConfigurations.p620.pkgs --apply` looks up every token (then its lower-case
  form) with `lib.attrByPath` under `tryEval`, returning the derivation `.name` or null. Attribute names are case
  sensitive, so no lower-casing first. Non-derivations (`discord.withVencord`) give null and stay Watch. No alias
  table.
- Family: resolved name with its trailing `-<digit>...` cut off (`foo-2.0` gives `foo`), the same cut on each
  inventory line. The rule fires only if no inventory family equals the family or starts with `<family>-`. Another
  version, a variant (`foo-unwrapped`, `ollama-cuda`) or an output keeps Watch.
- Fire conditions, all required: token resolved, inventory complete, eval-inputs check passes, family absent.
- GREEN reason: "Not in any host closure: `<name>` absent from the p620, razer and p510 derivation closures."
- The regex still selects candidates (filter only). The inventory and resolver run only if the regex matched at
  least one candidate. The report header gains one line: inventory size, or "closure inventory unavailable, no
  closure skips". The job log gets `[audit] inventory: N names in S s`.
- Fixture mode: `scripts/nixos-issue-audit.sh --fixture DIR` reads `open.jsonl` and `closed.jsonl` instead of `gh`,
  and `names.txt`, `resolved.json`, `eval-inputs.txt` instead of evaluating, and skips the release eval. New
  `scripts/test-nixos-issue-audit.sh` runs it and is added to `just test-guards`.
- Caching is deferred; if added later, the key must hash the host configuration, package lists and overlays, not only
  `flake.lock`.
- Expected on live data (re-checked under the family rule in the dry run): GREEN for zellij, ettercap, copyous,
  linux_zen, lima. WATCH for nvidia resume, tailscale, mutter and `discord.withVencord` (587751; discord is in the
  closure via `home/development/productivity.nix`).

## Steps

Prerequisite for Step 1: the owner sets `status: approved` on this plan, and that is committed alone as
`docs(plan): approve 2026-11-17-3008-audit-skip-unused (#3008)`. No implementation edit happens before that commit.

- **Step 1:** `scripts/nixos-issue-audit.sh` (lines 21-36 arg parsing, 58 release eval, 62-72 feeds, 92-116 helpers,
  123-230 `classify_one`, 257-266 header). Change, in this order:
  - Add `--fixture DIR` to the arg loop (set `FIXTURE`, update the `sed -n '2,16p'` usage range and usage text). With
    it set: copy `DIR/open.jsonl` and `DIR/closed.jsonl` into `$TMP`, skip the `gh api` calls, set `RELEASE=fixture`.
  - After the regex match (line 90), add `build_inventory` and `resolve_tokens`, called once and only if
    `OPEN_MATCHES + CLOSED_MATCHES > 0`. `build_inventory` writes `$TMP/names.txt` and sets `INV_OK=1` or `0`, using
    `timeout 240` per host and one 600 s deadline (`SECONDS` based; once spent, mark incomplete). Fixture mode copies
    `DIR/names.txt`, `DIR/eval-inputs.txt` and sets `INV_OK` from a `DIR/inventory-status` file (`ok` or anything
    else = incomplete). Live eval-inputs come from `jq -r '.nodes.root.inputs | keys[]' flake.lock`, lower-cased.
    Log `[audit] inventory: N names in S s`; on any failure log the reason and set `INV_OK=0`, never exit non-zero.
  - `resolve_tokens`: collect tokens from all matched titles (token rules above), write them as a JSON array, one
    `nix eval --json .#nixosConfigurations.p620.pkgs --apply` call returning `{token: name|null}`, under the
    remaining budget. Empty or failed output gives `{}` and nothing resolves. Fixture mode copies `DIR/resolved.json`.
  - In `classify_one`, add `elif closure_absent "$t"; then sev=GREEN; why=...; rec="No action."` directly before the
    final `else` (line 199). `closure_absent` returns 0 only if all fire conditions hold. It applies the family cut
    with logic that cuts the first `-<digit>` onward, tested for `foo-2.0`, `gnome-shell-extension-copyous-12`,
    `ettercap-0.8.5.1`, and a name with no version, and matches inventory families by equality or `family-` prefix.
  - Add one header line after line 266 with the inventory size or the unavailable text.
  - Check: `shellcheck scripts/nixos-issue-audit.sh`, then `bash scripts/test-nixos-issue-audit.sh` once Step 2 exists.
  - Traps: shellcheck clean; the spell-checker cannot parse char-class tricks (keep `${t,,}` style); no bash
    features beyond what the file already uses; no secrets read; nothing built, nothing on p510 beyond evaluation;
    keep lines readable and prose free of inline HTML.
- **Step 2:** `scripts/test-nixos-issue-audit.sh` (new, executable, `set -euo pipefail`) and
  `scripts/test-fixtures/nixos-issue-audit/` (new directories, one per case, each with `open.jsonl`, `closed.jsonl`,
  `names.txt`, `resolved.json`, `eval-inputs.txt`, `inventory-status`). Change: the script runs
  `nixos-issue-audit.sh --fixture DIR --out "$tmp"` per case and asserts severities with `jq` on `findings.jsonl`.
  Base payloads are the original upstream title, labels and body preview for the Issue 2998 items (zellij 588533,
  ettercap 588493, copyous 588377, discord.withVencord 587751, linux_zen 587387, lima 555161, nvidia resume 588180,
  tailscale 587975, mutter 587731). Cases from the spec:
  - GREEN: zellij, ettercap, copyous, linux_zen, lima.
  - WATCH: discord.withVencord, nvidia, tailscale, mutter, an unresolved `treewide:` title, a `home-manager:` title,
    a token matching an `eval-inputs.txt` entry.
  - WATCH when only another version (`foo-1.9`) or a variant (`ollama-cuda`, `foo-unwrapped`) is in the closure.
  - WATCH for all with `inventory-status` not `ok`, including a case with a partial `names.txt`.
  - WATCH for all with an empty `resolved.json` (`{}`).
  - CRITICAL and REGRESSION fixtures (a pipewire plus bluetooth open item, an incus item) keep the severity the old
    script gives on the same payloads; record the old results once from `origin/main` as expected values. These rules
    call `nix eval`, so the test stubs `nix` with a fake first on PATH. The stub must tell calls apart: enable checks
    return true, and a query ending in `.version` returns a version chosen by the ref (`github:NixOS/nixpkgs/<rev>`
    gives `1.0`, `nixos-unstable` gives `2.0`). The incus fixture must then reach CRITICAL (ours differs from
    unstable); add a second closed-security fixture with equal versions that must stay WATCH. The test asserts that
    at least one CRITICAL and one REGRESSION expectation exists, so parity cannot pass without exercising them.
  - Exit non-zero on the first failed assertion and print the case name.
  - Check: `shellcheck scripts/test-nixos-issue-audit.sh && bash scripts/test-nixos-issue-audit.sh`.
  - Traps: no network and no `gh` (fixture mode only); the fake `nix` and `nix-store` live in a temp dir on PATH;
    mark the file executable (`chmod +x`); no real payload carries secrets, but strip anything personal from the
    saved bodies; shellcheck and markdownlint run in pre-commit.
- **Step 3:** `Justfile:164-166` (`test-guards`): add `@bash ./scripts/test-nixos-issue-audit.sh` after the existing
  `test-bus-guard.py` line. Check: `just test-guards`. Traps: the Justfile recipe indentation is four spaces; keep
  the `@` prefix style of its neighbours.
- **Step 4 (lead):** Integrate and lint. First `git fetch origin && git merge origin/main`, so every later check runs
  on the final tree; if the merge changes the audit script, fixtures or host closures, rerun Steps 1 to 3 checks.
  Then run `shellcheck scripts/nixos-issue-audit.sh scripts/test-nixos-issue-audit.sh`,
  `just check-syntax`, markdownlint and the spell-checker on this plan and the spec, then `git status --porcelain`.
  Check: all exit 0, and `just check-syntax` prints no `Syntax error in` line (the recipe exits 0 even on a parse
  error and stays out of scope; scan its output or run `nix-instantiate --parse` per changed file).
  Traps: pre-commit formatters (shfmt, markdownlint) may rewrite files; re-stage and recheck;
  pre-push markdownlint lints whole files.
- **Step 5 (lead):** Inventory timing. Run the three `nix eval --raw ...toplevel.drvPath` plus `nix-store -qR` as in
  the spec and compare with its table (69 s / 67 s / 61 s eval, about 4 s each for `-qR`, about 21900 unique names).
  Then repeat from a fresh `git worktree` of the branch to prove all three toplevels evaluate from a clean checkout.
  Check: names count within a few percent of the spec; no host fails. Traps: evaluation only, never build p510; no
  deploy, switch or restart, so no bus announcement is needed; the fresh worktree goes beside the others, never in
  `~/.config/nixos`; remove it afterwards.
- **Step 6 (lead):** Dry run on live data. `--out` keeps only the report and findings, and the exit trap deletes the
  feeds, so capture them with a temporary `gh` shim first: a script on PATH that runs the real `gh`, tees its stdout to
  `$TMPDIR/feeds/<state>.jsonl` (state taken from the `state=` query argument), and passes it through. Run the
  branch script once through the shim. Then replay: a second shim `gh` that prints the saved file for the matching
  state serves both the branch script and `origin/main`'s script (no `--fixture` there) from identical payloads.
  Compare `jq -r '[.severity,.n,.title]|@tsv' <out>/findings.jsonl` of both.
  Check: the five expected items are GREEN with the closure reason,
  the three exposed ones stay WATCH, and CRITICAL and REGRESSION counts equal those of `origin/main` on the same
  payloads. Traps: only the audit script runs, so nothing is written to GitHub; the workflow's issue steps are not
  run.
- **Step 7 (lead):** Failure paths. Rerun Step 6 with `nix-store` hidden from `PATH` and again with the resolver
  forced to fail (for example an invalid `--apply` through a temporary edit that is reverted). Check: no item is GREEN
  because of the new rule and the header says the closure inventory is unavailable. Traps: revert any temporary edit
  before committing.
- **Step 8 (lead):** Commit, then open the PR. Commit as
  `chore(audit): skip upstream issues for packages in no host closure (#3008)`, with the Co-Authored-By trailers the
  session gives. If `origin/main` moved since Step 4, merge it again and rerun Steps 1 to 3 checks and Step 6 on the
  result. The PR description links intent, spec and plan and
  says which steps the coder and codex did. Check: `gh pr view` shows the three links; CI green. Traps: write prose
  to a file and pass `--body-file` (the bus guard matches command text); never commit on `main` or in
  `~/.config/nixos`; no backticks inside `git commit -m`; verify the push landed by comparing the remote head.
- **Step 9 (lead):** After merge, the owner runs one `workflow_dispatch` of `nixos issue audit` (it writes the rolling
  issue as normal). Check: the job log shows `[audit] inventory: N names in S s` with S under 720 (12 min) and the
  rolling issue lists the expected GREEN items with the closure reason. Traps: no deploy is involved, so no
  `just p620` is needed; if a later change adds a deploy, announce on the agent bus first and use
  `AGENT_BUS_ANNOUNCED=1 ALLOW_BRANCH_DEPLOY=1 just p620` or `just deploy-via-p620 razer` after merging `origin/main`;
  p510 is never built or deployed without the owner's OK.

## Tests

- `bash scripts/test-nixos-issue-audit.sh` (Step 2) and `just test-guards` (Step 3): fixture severities, fail-closed
  cases, and CRITICAL and REGRESSION parity with the old script.
- The fixture test injects names and resolved tokens, so the real inventory and resolver are covered only by Steps 5
  to 7.
- Lint: `shellcheck` on both scripts, `just check-syntax`, markdownlint and the spell-checker on spec and plan.

## Rollback

Merge the PR as a squash commit, so one `git revert <sha>` undoes it (a merge commit would need `-m 1`).
After the revert the script returns to the keyword-only behaviour and the `Justfile` line goes with it. No
workflow, host, secret or deployed state is touched, so nothing else needs undoing. If runtime on the runner exceeds
the budget after merge, the rule already fails closed to Watch; revert only if the nightly job nears its 20 minute
limit.
