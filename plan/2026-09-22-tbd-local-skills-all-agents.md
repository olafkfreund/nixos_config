---
status: approved
issue: TBD
spec: spec/2026-09-22-tbd-local-skills-all-agents.md
---

# Plan: Declare every local skill once, install it for each agent

## Approved decisions (from the spec)

- **Agent directories**, written in exactly one place:
  - `claude` = `.claude/skills`
  - `agents` = `.agents/skills`, read by both Codex 0.155.1 and Antigravity 1.2.5
  - `codex` = `.codex/skills`, Codex only
  - No Pi and no `~/.gemini/skills` target: no installed agent reads either.
- **Which agents get which skill:**
  - `claude` + `agents`: `gog`, `notebooklm`, `artifact-workflow` (#1832),
    `dns`, `obsidian`, `1password`, plus the six moved in: `nixos-standards`,
    `fides`, `backstage-patterns`, `linkedin-post`, `reddit-post`,
    `cosmic-ui-design-skill`
  - `claude` + `codex`: `agent-bus`, because Antigravity has no agent-bus MCP
  - `claude` only: `second-opinion` (#1831) and `ask-ollama-cloud`
    (#1928, #1929)
- **Link style:** `home.file."<dir>/<name>" = { source; recursive = true;
  force = true; }`. That means per-file links inside a real directory, as
  today, so sibling entries owned by nixarchy and nix-skills are untouched.
  `force` replaces the old regular files once, since `backupFileExtension`
  is not set.
- **`notebooklm`** gets a `pkgs.runCommand` tree: a copy of `./notebooklm`,
  plus `reference.md` and `references` linked from `nlmData`.
- **`dns.sh`** is marked executable in git, and its `executable = true`
  override goes away.
- **Syncthing:** the `.stignore` step runs *before* `linkGeneration`. The
  exact form is `entryBetween [ "linkGeneration" ] [ "writeBoundary" ]`: it
  still runs after HM's write boundary, but closes the window in which new
  store links look syncable (#1960). This is safe because the old `.stignore`
  symlinks are gone since #1962, and the script replaces a leftover symlink
  rather than writing through it.
- **Dropped:** every `.codex/skills/{gog,notebooklm}` and
  `.gemini/skills/{gog,notebooklm}` entry.
- **Not migrated:**
  - `parr-run` and `run-aws-demo` (private infrastructure; this repo is public)
  - the 5 `skills`-CLI skills: `ci-cd-pipelines`, `clean-code`,
    `super-brainstorm`, `skill-forge`, `frontend-design`
- **Out of scope** (follow-up in nix-skills): Antigravity sees nix-skills
  twice, through `.agents/skills` and `.gemini/config/skills`.

## Steps

All paths are relative to the repo root. `S` = `home/development/claude-code-skills`.

1. **Import the six skills.**
   `cp -r ~/.claude/skills/{nixos-standards,fides,backstage-patterns,linkedin-post,reddit-post,cosmic-ui-design-skill} S/`,
   then `git add` them.
   → verify:
   - `diff -r` of each against its source is empty.
   - Re-run the spec's secret scan on `S/`; it finds only the known
     placeholders.
   - The pre-commit hooks pass.
2. **Fix the `dns.sh` mode.** `chmod +x S/dns/scripts/dns.sh &&
   git update-index --chmod=+x S/dns/scripts/dns.sh`
   → verify: `git ls-files -s` shows `100755`.
3. **Replace the per-file lines** in `S/default.nix`. Delete lines 46–130
   except the `claude-code-mastery` link (46–47), and add in their place:
   - `agentDirs` and `localSkills` exactly as in the decisions above
   - `notebooklmTree`, in the file's `let` block next to `nlmData`
   - `home.file = lib.mkMerge (lib.mapAttrsToList … localSkills);`, using
     `lib.genAttrs'` (present in the pinned nixpkgs; checked)

   Keep the "why" comments that still apply as one-liners next to their
   table rows: the reason for Claude-only, the MCP reason, the notebooklm
   reference rationale. Delete the comments about per-file choices, which
   the table replaces.
   → verify:
   - The eval in Tests §2 shows exactly the expected paths, and
     `nix flake check` passes.
4. **Change the activation order** in `home/syncthing-stignore.nix:155`:
   `entryAfter [ "linkGeneration" ]` becomes
   `entryBetween [ "linkGeneration" ] [ "writeBoundary" ]`, and the comment
   above it is rewritten to give the #1960 reason.
   → verify: Tests §3.
5. **Build all hosts**: Tests §1.
6. **Deploy to p620**: `nixos-rebuild switch`, then Tests §4 and §5.
7. **Deploy to razer and p510**: the same, then Tests §4 on each.
8. **Remove the old copies.** After all three hosts are switched, the six
   moved skills are HM links everywhere, and Syncthing ignores them. No
   manual deletion is needed. Confirm with `find ~/.claude/skills/<name>
   -type f` (empty) on each host.

Steps 1–4 go in one commit: `feat(skills): declare local skills once, install
for every agent (#TBD)`. Steps 5–8 are deploys, not commits.

## Tests

1. **Build:**
   ```bash
   nix flake check
   for h in p620 razer p510; do
     nix build .#nixosConfigurations.$h.config.system.build.toplevel --no-link
   done
   ```
   Expect all to succeed.
2. **File table:**
   ```bash
   nix eval --json .#nixosConfigurations.p620.config.home-manager.users.olafkfreund.home.file \
     --apply 'f: builtins.filter (n: builtins.match "\\.(claude|agents|codex|gemini)/skills/.*" n != null) (builtins.attrNames f)'
   ```
   Expect, counted as distinct skill names (the second path segment):
   - `.claude/skills`: 21. That's 15 local skills (9 existing + 6 moved),
     `claude-code-mastery`, the 4 nix-skills, and `nixi` (installed by the
     nixi-nixarchy module; out of scope). This was 20 in the approved plan,
     which missed `nixi`; corrected during implementation.
   - `.agents/skills`: 16. That's 12 local skills (all except
     `second-opinion`, `ask-ollama-cloud` and `agent-bus`) and the 4 nix-skills.
   - `.codex/skills`: `agent-bus` only.
   - `.gemini/skills`: none.
3. **Ignore file:** the built `claude-stignore` has a line for each of the
   six moved skills (`/skills/nixos-standards`, `/skills/fides`, …) and none
   for `/skills/parr-run` or `/skills/run-aws-demo`.
4. **After switch:**
   ```bash
   ls ~/.claude/skills ~/.agents/skills ~/.codex/skills
   readlink ~/.agents/skills/gog/SKILL.md        # /nix/store/…
   test -x ~/.claude/skills/dns/scripts/dns.sh
   test ! -e ~/.codex/skills/gog && test ! -e ~/.gemini/skills/gog
   test -f ~/.claude/skills/parr-run/SKILL.md && test -f ~/.claude/skills/run-aws-demo/SKILL.md
   curl -s -H "X-API-Key: $KEY" '127.0.0.1:8384/rest/db/ignores?folder=claude-config' | grep nixos-standards
   ```
5. **Agents see the skills:** a fresh `codex` session and a fresh `agy`
   session each list `artifact-workflow` and `nixos-standards`.

## Rollback

- **Code:** `git revert` the feature commit, then `nixos-rebuild switch`.
  HM removes the new links.
- **The six moved skills:** after rollback, HM has removed them and nothing
  recreates them. Restore with
  `cp -r home/development/claude-code-skills/<name> ~/.claude/skills/`
  from the reverted-from commit, and Syncthing carries them back to the other
  hosts.
- **One bad host:** `nixos-rebuild switch --rollback` on that host. The other
  hosts are unaffected, because the moved skills are Syncthing-ignored on
  hosts that have switched.
