---
status: approved
issue: 3008
author: olafkfreund
---

# Intent: Nightly audit skips upstream issues for packages no host runs

Predecessor: Issue 2998, `intent/2026-11-17-2998-upstream-audit-triage.md` (open question 3).

## Problem

The nightly audit (`.github/workflows/nixos-issue-audit.yml`, running `scripts/nixos-issue-audit.sh`)
puts an upstream issue on the Watch list whenever its title or first 400 body characters match the
inventory regex (`REGEX`, script step 3). The regex is a hand-kept list of keywords, not a list of
what the hosts really contain. `classify_one` then checks only a few hard-coded cases (pipewire +
bluetooth, tailscale dns, hyprland, plymouth, incus). Everything else falls to the default:
"Inventory keyword matched but specific exposure not auto-verified. Needs human triage."

The result is visible in Issue 2998. Of its 15 Watch items, the triage suspected these were in no host
closure: zellij (588533), ettercap (588493), `gnomeExtensions.copyous` (588377), `discord.withVencord`
(587751, we ship vesktop), `linux_zen` (587387) and lima (555161). These are suspected skips, not proven
ones: the triage grepped the repository and did not evaluate closures (2998 intent, Constraints), so a
transitive dependency could have been missed. The matching keyword for each is also unverified: the
regex has no `virtiofsd` entry, so the real cause needs the original issue payloads (title, labels,
body preview, open or closed stream). Each item cost a manual look, and the pass repeats every night.

A second workaround already exists: the GREEN rule in `classify_one` lists package names by hand
(`steam|cargo|amphetype|bambu|...`). That list only grows when someone notices a miss.

## Proposed outcome

The audit decides "do we run this?" from the real hosts, not from a keyword list:

- Build, once per run, an inventory of package names and enabled options for p620, razer and p510
  from evaluation only. The source is undecided (open question 1): a derivation closure also holds
  build dependencies and sources, while `systemPackages` plus Home Manager packages misses services
  and transitive dependencies. "Exposure" must be defined first: runtime, build and evaluation
  dependencies all count, because `flake.nix` already records an eval-time dependency on a package no
  host installs (the zen-browser pin).
- For each upstream issue, extract the package or module it names (the title prefix before `:`).
- A skip needs positive evidence. GREEN with "Not in any host closure" is allowed only when the name
  resolves to a known identity (attribute, derivation name or module path), the inventory for all
  three hosts is complete, and neither appears in it. Attribute names, derivation names, variants
  and module paths are different identifiers (2998 already hit `t3-code` against `t3code`).
- Unresolved identity, an unmapped module, an incomplete inventory, or one host failing to evaluate
  means Watch, never GREEN. A missed skip costs one line, a wrong skip hides real exposure.
- Scope of the guarantee: the new skip rule must fail to Watch. Whether existing checks are repaired
  too is open question 7: today `host_eval_bool` turns an evaluation error into `false`, so the
  hyprland, plymouth and incus rules go GREEN after a failure. Where the new rule sits relative to
  the existing severity rules (before or after them) must also be stated.
- Existing rules (pipewire, tailscale, hyprland, plymouth, incus, security cross-check) keep their
  order and behaviour, except as open question 7 decides. The hand-kept GREEN package list can be
  dropped once the closure check covers it.
- Candidate selection is unchanged: the regex still discards unmatched issues before classification,
  and this task only filters candidates it already selects (open question 8). A regex match does not
  mean Watch: earlier rules also yield GREEN and REGRESSION.

Success looks like re-running the audit against the Issue 2998 data: the six suspected items become
GREEN once verified, and the items the triage found exposed or unproven (for example nvidia resume 588180,
tailscale 587975, mutter 587731) stay on Watch.

## Affected users and systems

- The owner, who triages the rolling "NixOS upstream audit" issue (label `nightly-audit`).
- `scripts/nixos-issue-audit.sh` and `.github/workflows/nixos-issue-audit.yml`.
- p620, razer and p510 are read by evaluation only. Nothing is built, deployed or restarted, and
  p510 is never built.
- CRITICAL and REGRESSION findings still open tracking issues (`upstream-audit`); that path should
  be unchanged.

## Constraints

- Evaluation cost and the 20 minute job limit. Instantiating three toplevels on a CI runner may be
  slow; the closure set must be computed once, not per issue.
- The runner has no host-only inputs. Anything needing secrets, agenix paths or an unlocked
  `/etc/nixos` will fail there, so the check must evaluate in a clean checkout.
- Matching is by name, so it is fuzzy: a nixpkgs issue title does not always carry the attribute
  name, and a package can arrive as a transitive dependency. A false skip is worse than a false Watch.
- Keep the script's `bash` + `jq` + `nix` shape; no new dependencies, no API keys (Issue 1831).
- Markdown and shell must pass the repo lint (shellcheck, markdownlint, the spell-checker).

## Open questions

1. Which inventory counts as exposure: derivation names of the toplevel closure (includes build
   inputs), `systemPackages` plus Home Manager packages (misses transitive and service packages), or a
   union that also covers evaluation dependencies? Recommend a runtime closure (toplevel store paths
   evaluated, not built) plus the evaluation dependencies, defined in the spec. Any evaluation
   failure on any host falls back to Watch.
2. How is the package identity resolved from a title? Recommend the token before the first `:`,
   lower-cased, mapped through a small alias table (`gnomeExtensions.x`, `discord.withVencord`,
   `t3-code`). An unmapped or unknown shape stays Watch.
3. Should skipped items disappear from the report or appear under GREEN with the reason? Recommend the
   GREEN section, so a wrong skip can be seen and corrected.
4. Should generic subsystem keywords (nvidia, docker, nfs, pipewire) also be checked against enabled
   options? Recommend yes for the options already evaluated by `any_host_enables`, and no new option
   table in this change.
5. Can the nightly runner afford the evaluation within the timeout, and how is it measured without
   publishing? The workflow unconditionally rewrites the rolling audit issue and can open tracking
   issues, so a branch `workflow_dispatch` would write to production. Recommend a local or dry-run
   measurement that skips the issue steps. Caching is deferred; if added, the key must cover the
   host configuration, package lists and overlays as well as `flake.lock`, since the lock alone can
   hide a newly installed package.
6. Should the 2998 data be a regression fixture? Recommend a saved sample of the original upstream
   payloads (title, labels, body preview, open or closed stream), not rendered findings, checked by a
   `just test-guards`-style script test.
7. Does the Watch-on-failure guarantee cover only the new skip rule, or also repair the existing
   `host_eval_bool` behaviour that turns evaluation errors into `false`? Recommend the new rule only,
   and a separate issue for the existing checks.
8. Does this task only filter existing candidates, or also replace regex candidate selection?
   Recommend filter only.

## Decision

Approved by the owner on 2026-11-17, with the recommendation given for each open question above.
