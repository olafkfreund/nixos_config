# Update Codex CLI

Tracks OpenAI's GitHub release tarballs (`pkgs/codex-bin`). The nightly
`package-autoupdate` workflow does steps 1–2 on its own.

## Prerequisites

- [ ] `git status` clean
- [ ] `gh auth status` OK
- [ ] Current `codex --version` captured for the commit body

## Steps

1. **Update the pin.**

   ```bash
   ./scripts/update-codex-bin.sh                 # current vs latest
   ./scripts/update-codex-bin.sh --write latest  # rewrite version + hashes
   ```

2. **Build.** The install check runs the stdin guard test.

   ```bash
   OUT=$(nix build --no-link --print-out-paths .#codex-bin)
   $OUT/bin/codex --version          # must match target
   ```

3. **Guard test.** Confirm the option lists in `codex-wrapper.sh` still
   match `codex --help`.

   ```bash
   sh pkgs/codex-bin/guard-test.sh
   ```

4. **Host build.** `just test-host p620`

5. **Branch, commit, PR.** Never deploy from the PR branch.
