---
status: draft
issue: 2214
intent: intent/2026-10-08-2214-remove-dev-utils.md
---

# Spec: remove the dev-utils flake app

## Design

Two deletions, nothing else:

- `flake.nix`, in `apps.x86_64-linux`: delete the four-line `dev-utils = { type = "app"; program = ...; };` block,
  the last entry before the set's closing `};`.
- `tools/default.nix`: delete the `# Development utilities` comment and the `dev-utils = pkgs.writeShellApplication {
  ... };` attribute, its last attribute. The file's closing `}` stays, and so do `deploy` and `test`.

### Ordering with PR #2213

PR #2213 (Issue #2205) deletes the `build-live` blocks that sit directly above both of these in the same two files.
Hunks that touch each other conflict, so this branch is rebased onto `main` after #2213 merges, and the edits are
made against that tree. If #2213 is still open when the plan is approved, implementation waits for it.

## Alternatives rejected

- **Fix it** (remove the space, change the glob to `nixpkgs-fmt .`). Rejected in the intent: it would revive a duplicate
  of Justfile recipes that nobody has missed, since it has never run.
- **Leave it.** Rejected: a broken entry point that advertises itself in `nix flake show` misleads whoever reaches for it.

## Risks

"Does not break anything" is the approval condition, so each risk is proven absent, not argued:

- **A host changes.** The apps are not part of any system. Proven if the toplevel `drvPath` of p620, razer and p510 is
  byte-identical before and after.
- **Something calls the app.** Nothing in the tree references `dev-utils`, apart from `flake.nix` and
  `tools/default.nix` and the artifacts. Proven by grep.
- **The remaining apps break.** `deploy` and `test` share `tools/default.nix`. Proven if both still build, with the same
  `drvPath` as before.
- **CI references the app.** Already covered by the grep, which includes `.github/`.

## Verification

1. Record the toplevel `drvPath` of all three hosts, and the `drvPath` of the `deploy` and `test` apps, before the
   edit. Repeat after the edit: every value is identical.
2. `nix eval .#apps.x86_64-linux --apply builtins.attrNames` gives `[ "deploy" "test" ]`.
3. `nix build` of the `deploy` and `test` app programs succeeds.
4. `grep -rn "dev-utils" --exclude-dir=.git .` finds nothing outside `intent/`, `spec/` and `plan/`.
5. `just check-syntax` and `nix flake check --no-build` pass.
