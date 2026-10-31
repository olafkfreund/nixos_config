---
status: draft
issue: 2577
author: olafkfreund
---

# Intent: Fix what the repo-wide review found

## Problem

A repo-wide review (six Fable reviewers by area, each finding cross-checked
read-only by Codex and agy, high-severity ones re-checked by hand) returned
80 findings. The full table, with file:line and both verdicts, is in #2577.
They fall into four groups.

**Bugs that bite today** (all confirmed by both models unless noted):

- `nhs` pins the wrong nixpkgs. `splice_nixpkgs_node nixpkgs` in
  `scripts/update-commit-deploy.sh:200` rewrites the lock node literally
  named `nixpkgs`, which is agenix's input; the root's is `nixpkgs_8`.
  The ground-truth splice has never touched the nixpkgs we build (tooling-1).
- Justfile recipes use `$$`, a Makefile escape. just passes it to sh, so
  `$$REPLY` is the shell PID plus `REPLY`: every confirm prompt and loop
  using it is broken (tooling-2).
- `greetd.restartIfChanged = false` on p620, which has no greetd, creates a
  body-less unit: `greetd.service` is `bad-setting` live (hosts-1).
- p510's `tailscale-serve` oneshot has no timeout and can hang boot's
  `multi-user.target` forever when tailscale is logged out (hosts-2).
- `packages.x86_64-linux.neuwaita-icon-theme` in `flake.nix` has a mangled
  installPhase and can never build; it duplicates `pkgs/neuwaita-icon-theme`
  (hosts-3, pkgs-1).
- Generation cleanup runs after `nix-gc`, so it frees nothing until the next
  week's GC (services-3).
- `mkEnableOption { … }` with an attrset in six modules breaks option docs
  and nixd hover (services-2, home-10).
- Smaller: CI turns some real eval errors into a pass (tooling-5); two
  build recipes report success on failure for lack of pipefail
  (tooling-3, -4); `deploy-all-parallel` reports done before the deploys
  finish (tooling-11); scream-ivshmem user service can never start
  (hosts-6); the wl-paste shim has no shebang (pkgs-2); `whatsapp-mcp` pins
  `rev = "main"` (pkgs-3); a pre-commit hook never runs because of a case
  mismatch (tooling-9); a bogus git key and a broken playerctl script
  (home-12, pkgs-10).

**Security:**

- A plaintext VNC password sits in `hosts/p510/configuration.nix` in a
  public repo (hosts-8). Deleting the line does not un-publish it.
- `api-ollama` is decrypted 0644, against the #1831 rule for metered keys
  (services-6, modules-rest-3; agy rejects the first proposed fix, 0640,
  because the `users` group still reads it).
- The GitHub token is exported as `GH_TOKEN` into every interactive shell on
  all hosts by splashboard (home-2).
- FlareSolverr (headless Chromium) runs SCHED_FIFO on p510 (hosts-9);
  `obsidian-mcp-rest` wrapper takes the key from env without pipefail
  (pkgs-11).

**Dead code** — modules, options, packages, scripts, recipes and flake
inputs that nothing imports or reads, roughly 3,000 lines: the
`network-stability`/`secure-dns` modules, `modules/nixos/` and
`modules/packages/`, `modules/microvms/`, four unimported service modules,
eight unimported host files, the unused profile library, unread options set
by hosts (`queueDepth`, `hostKeys`, `enableEnvironmentVariables`, six HM
feature flags), a root `while true` storage monitor writing a file nothing
reads, unused flake inputs, and Justfile recipes and CI jobs aimed at files
that do not exist. Two of the proposed deletions were refuted by both
models and stay: `tfm.nix` is enabled on p620/razer (only `flow-desktop`
is unused), and `home/development/claude-code` backs a flake package.

**Simplification** — duplicated config: p620/razer share ~150 identical
lines; `nixpkgs-unstable` is locked to the same rev as `nixpkgs` yet
instantiated twice; direnv is enabled in four places; zsh/bash aliases
duplicated; `nix.gc`/`nix.optimise` declared twice (p510 optimises twice a
week); the Plasma, COSMIC-theme and lan-mouse HM modules load on every host
ungated; four copies of one MCP secret-loading block.

## Proposed outcome

- `nhs` splices the root nixpkgs node; Justfile prompts work; p620 has no
  `bad-setting` unit; p510 cannot hang at boot on tailscale; every flake
  package builds; `just validate` and CI fail on real errors.
- No world-readable metered key; no token in every shell's environment;
  no plaintext credential in the tree.
- Dead modules, options, files and inputs are gone, and `just test-host`
  for p620 and razer builds with an unchanged closure where the change is
  meant to be pure deletion.
- Each change lands in a small PR by group, so one bad change reverts alone.

## Affected users and systems

All three hosts. p620 and razer through shared modules and their own
configs; p510 through `tailscale-serve`, FlareSolverr, the VNC line,
`p510_home.nix` and every shared module. `nhs`, the Justfile and CI.

## Constraints

- p510 is never built or deployed without asking. Changes touching it are
  committed and built for p620/razer only; p510's deploy waits for you.
- Deletion of dead code must not change the closure of any host. Verify by
  comparing `nix eval .#nixosConfigurations.<h>.config.system.build.toplevel`
  out-paths before and after, where the change claims to be pure.
- Announce on the agent bus before any deploy.
- Implementation runs through a Workflow (as requested), only after the plan
  is approved; coders work in worktrees, review by a fresh Opus agent.

## Open questions

1. **Scope.** All four groups, or bugs + security first and dead code /
   simplification as a follow-up? I recommend bugs + security + dead code
   now (low risk, closure-checkable) and the simplification group, which
   restructures p620/razer and the nixpkgs-unstable input, as a later task.
2. **VNC password.** It is already public in git history. Is
   `p510remote` used anywhere else, and do you want it rotated? Removing
   the line is all this task can do.
3. **GH_TOKEN in shells.** Was exporting it to every shell deliberate
   (for `gh` without login)? The alternative is `gh auth login` per host or
   a wrapper that reads the agenix file only when `gh` runs.
4. **p510.** May I build p510 to verify the changes that touch it (build
   only, no deploy)?
