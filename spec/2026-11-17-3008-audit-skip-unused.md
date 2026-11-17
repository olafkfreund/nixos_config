---
status: draft
issue: 3008
intent: intent/2026-11-17-3008-audit-skip-unused.md
---

# Spec: Nightly audit skips upstream issues for packages no host runs

## Design

One new rule in `scripts/nixos-issue-audit.sh`, fed by one inventory built per run. The workflow file does not
change. The new rule only ever turns a default-Watch candidate into GREEN; every failure path leaves it Watch.

### Measurements (dev machine, nixos-3008 worktree, lock rev d5cc683, evaluation only, nothing built)

| What | Time | Result |
| --- | --- | --- |
| `environment.systemPackages` names, p620 | 11 s | 1021 names, misses services and transitive deps |
| `config.system.build.toplevel.drvPath`, p620 / razer / p510 | 69 s / 67 s / 61 s | one `.drv` path each |
| `nix-store -qR` on each `.drv` | 4.7 s / 4.7 s / 3.7 s | 32667 / 31534 / 26405 derivations |
| Union of the three, hash and `.drv` stripped | n/a | 21908 unique names |
| Resolve 10 attribute names in one `nix eval` | 8.4 s | same 8.4 s for 1 name, so batch them |

The last real CI run (run 44000548716, 2026-11-17) took about 50 s end to end, so the 20 minute limit has ample
room. The new cost is about 3.5 min on this machine; assume 2 to 3 times that on a runner, so about 10 min worst case.
The audit evaluates only the p620 release string on the runner (`release: 26.11` in that log). That does not prove
three full toplevels evaluate in a clean checkout, and the 2 to 3 times factor is an estimate, not a bound. Hence the
overall timeout below and verification step 3b. All inventory and resolver work shares one 600 s budget, so a failure
still leaves most of the workflow's 20 minutes to publish a Watch report.

### Decisions carried from the approved intent

1. Exposure (open question 1) is the derivation closure of each host toplevel, from `nix eval` of `drvPath` and
   `nix-store -qR`. This holds runtime, build and source derivations, so it is a superset of what runs. A superset
   only makes the check more cautious. Evaluation-only dependencies are kept in a
   separate list, not in the inventory: the root input names of `flake.lock` (`zen-browser` and the like) as
   `eval-inputs.txt`. Before dismissing a candidate, the lower-case token and family (decision 2) are compared with that
   list, equal or prefix in either direction; a hit, or any doubt, keeps Watch. Dependencies used only during
   evaluation inside an input are not enumerated; they stay Watch only through this name match. Each host gets
   `timeout 240`; a timeout, an error, or fewer than 1000 lines for any host marks the whole inventory incomplete,
   so one host failing after partial output also disables every skip.
2. Identity (question 2) is resolved against the hosts' own package set, not an alias table. Token: drop a leading
      `nixos/`, then the text before the first `:`, else the first word. It must match `^[A-Za-z0-9_.+-]+$`. Tokens
   naming a module or subsystem rather than a package (`home-manager`, `nixos`, `nix`, `systemd`, `treewide`,
   `modules`, `services`, `programs`) are never resolved and stay Watch, because a missing executable does not
   prove a module absent (the flake imports `home-manager.nixosModules.home-manager`). The first-word fallback applies
   only when the title has no `:` and the word is not on that list. One batched
   `nix eval .#nixosConfigurations.p620.pkgs --apply` looks up each token (then its lower-case form, for titles like
   "Ettercap through ...") with `lib.attrByPath` under `tryEval`, and returns the derivation `.name`, or null. This
   deviates from the recommended lower-casing: attributes are case sensitive (`gnomeExtensions.copyous`). It also
   removes the alias table: `linux_zen` resolves to `linux-zen-7.3.4`, `discord.withVencord` (a function, not a
   derivation) does not resolve and stays Watch. The p620 package set carries the repo overlays.
3. A skipped item goes to GREEN with the reason (question 3): "Not in any host closure: `<name>` absent from the
   p620, razer and p510 derivation closures."
4. No option table (question 4). The existing `any_host_enables` checks stay as they are.
5. Rule placement: a new `elif` directly before the final `else` of `classify_one`, after every existing rule.
   Existing rules keep order and behaviour (question 7: not repaired here). It fires only if the token resolved,
   the inventory is complete, the eval-inputs check passes, and the package family is absent. The family is the
   resolved name with its trailing `-<digit>...` version cut off (`foo-2.0` gives `foo`); each inventory line is cut
   the same way. The rule fires only if no inventory family equals or starts with `<family>-`. Another version
   (`foo-1.9`), a variant (`foo-unwrapped-2.0`, `ollama-cuda`) or an output therefore keeps Watch. Counterexamples
      from this repo, p510 `ollama-cuda` and razer `linuxPackages_latest`, become fixtures. Anything else falls to the
   existing Watch default. The hand-kept GREEN package list
   stays; dropping it is a follow-up once this rule has run for a while.
6. Filter only (question 8): the regex still selects candidates. The report header gains one line: inventory size,
   or "closure inventory unavailable, no closure skips".
7. Costs only when needed: the inventory and resolver run only if the regex matched at least one candidate.
8. Fixture (question 6): `scripts/nixos-issue-audit.sh --fixture DIR` reads `open.jsonl` and `closed.jsonl` instead of
   calling `gh`, plus `resolved.json` and `names.txt` instead of evaluating, and skips the release eval. The fixture
   holds the original upstream payloads (title, labels, body preview) for the Issue 2998 items. New
   `scripts/test-nixos-issue-audit.sh` runs it and asserts severities, and is added to `just test-guards`.
9. Question 5: measured above. Caching deferred. If added later, its key must hash the host configuration, package
   lists and overlays, not only `flake.lock`.

### Expected result, checked against the real closure

Resolved names absent from the closure: `zellij-0.46.0`, `ettercap-0.8.5.1`, `gnome-shell-extension-copyous-12`,
`linux-zen-7.3.4`, `lima-2.3.0`. Present: `mutter-51.0`, `tailscale-1.104.6`. `nvidia` does not resolve. So five of
the six suspected items go GREEN, and nvidia resume, tailscale and mutter stay Watch.

The intent's sixth item is corrected by evidence: `discord-1.0.168` is in the closure
(`home/development/productivity.nix` enables `discord`), so 587751 must stay Watch. The triage assumption that only
vesktop ships was wrong, which is the case this design exists to catch.

## Alternatives rejected

- `systemPackages` plus Home Manager packages: 11 s but 1021 names; misses services and transitive deps, so false skips.
- Alias table keyed on lower-cased titles: hand-kept, and lower-casing breaks attribute lookup. Attribute resolution
  against the real package set replaces it.
- Matching the title token directly against inventory names: `linux_zen` against `linux-zen-7.3.4` needs the underscore
  mapping, and `pname` collisions (`linux`) hide skips. Full resolved name equality avoids both.
- Building or `nix path-info` of outputs: needs a build; not allowed on p510 and slow elsewhere.
- Per-issue evaluation: 8 s per call, about 5 min for 40 candidates. Batch once instead.
- Repairing `host_eval_bool` now: widens scope (question 7). File a separate issue.
- CI cache of the inventory: a lock-only key hides newly installed packages. Deferred (question 5).
- Replacing regex candidate selection: out of scope (question 8).

## Risks

- A false skip hides real exposure. Mitigations: skip needs token, resolution, complete inventory and absence; the
  closure is a superset; GREEN shows the reason in the report. Residual: the title names a package other than the
  one the issue is about (the lima issue also concerns `virtiofsd`, which is in the closure). Accepted, as before.
- A first word that resolves to an unrelated attribute (a title starting with a common word) could skip an issue.
  Only absent package families skip, module and subsystem tokens are excluded, and the body is not read. Accepted
  for ordinary package names only.
- Family matching is conservative, not complete: a package renamed between versions looks absent. The expected
  results below are re-checked under the family rule in the dry run, not assumed.
- Runner time or memory: three toplevel evaluations on a smaller machine. Fail-closed through the 240 s per-host
  timeout, but the cost is a night of no skips. Nothing measured on CI itself, since a branch `workflow_dispatch`
  would write the production audit issue.
- `nix eval ... drvPath` writes `.drv` files into the runner store: harmless on CI, and on a dev host it does only
  that (no build). Never run for p510 beyond evaluation, which this is.
- Fixtures inject resolved names and inventory, so the resolver and inventory construction are covered by the manual
  dry run and the failure-path steps below, not by the fixture test.

## Verification

1. Syntax and lint: `shellcheck scripts/nixos-issue-audit.sh scripts/test-nixos-issue-audit.sh`, markdownlint and the
   spell-checker on this file and the plan, and `just check-syntax`.
2. Fixture test: `bash scripts/test-nixos-issue-audit.sh` exits 0 and `just test-guards` runs it. Saved payloads are
   one set, used for both the old and the new script, so the comparison is stable. It asserts:
   - GREEN for zellij, ettercap, copyous, linux_zen, lima;
   - WATCH for discord.withVencord, nvidia, tailscale, mutter and an unresolved `treewide:` title;
   - WATCH for a `home-manager:` title (module token) and for a token matching an eval-inputs entry;
   - WATCH when only another version (`foo-1.9`) or a variant (`ollama-cuda`, `foo-unwrapped`) is in the closure;
   - WATCH for all with an incomplete inventory, including a host that failed after partial output;
   - WATCH for all when the resolver output is empty or failed;
   - CRITICAL and REGRESSION items get the same severity from the old and the new script on the same payloads.
3. Inventory timing: run the three `nix eval --raw .#nixosConfigurations.<host>.config.system.build.toplevel.drvPath`
   plus `nix-store -qR` as measured above, and compare with the table. 3b: repeat from a fresh `git worktree` of the
   branch with no issue-writing step, to check that all three toplevels evaluate from a clean checkout.
4. Dry run on live data, which writes nothing to GitHub because only the audit script runs, not the workflow's issue
   steps: `bash scripts/nixos-issue-audit.sh --out "$TMPDIR/audit-out"` (needs `gh` auth, read only). Then
   `jq -r '[.severity,.n,.title]|@tsv' "$TMPDIR/audit-out/findings.jsonl"` and check that the expected items are
   GREEN with the closure reason, that the three exposed ones remain WATCH, and that CRITICAL and REGRESSION counts
   equal those of `origin/main` run against the same saved `open.jsonl` and `closed.jsonl` (`--fixture`), not two
   live fetches.
5. Failure path: run the dry run with the toplevel eval forced to fail (for example `PATH` without `nix-store`) and
   again with the resolver forced to fail, and confirm no item is GREEN because of the new rule and the header says
   the inventory is unavailable.
6. After merge, one `workflow_dispatch` by the owner (it writes the rolling issue as normal) confirms the runtime in
   the job log lines `[audit] inventory: N names in S s`, to be under 12 min.
