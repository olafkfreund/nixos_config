---
status: draft
issue: TBD
intent: intent/2026-09-22-tbd-local-skills-all-agents.md
---

# Spec: Declare every local skill once, install it for each agent

## Facts this design rests on

Measured on p620, 2026-09-22.

- **Which directories each agent reads**, found by searching each binary for
  its skill paths:
  - Codex 0.155.1 reads `~/.agents/skills` and `~/.codex/skills`.
  - Antigravity (`agy` 1.2.5) reads `~/.agents/skills` and
    `~/.gemini/config/skills`.
  - Gemini CLI and Pi are not installed. The `~/.gemini/skills` copies of
    `gog` and `notebooklm` are read by nothing.
- **Where the 13 unmanaged skills came from:**
  - The `skills` CLI lock (`~/.agents/.skill-lock.json`) records 5 of them:
    `ci-cd-pipelines`, `clean-code`, `super-brainstorm`, `skill-forge`
    (AbsolutelySkilled) and `frontend-design` (anthropics/skills).
  - The other 8 were written by hand.
- **Sensitive content in the 8 hand-written skills** (scanned for secrets,
  IPs, account IDs, private hosts):
  - `run-aws-demo` contains a real AWS account ID (`SKILL.md:76`,
    `conductor.sh:6`) and `factory.freundcloud.com`.
  - `parr-run` names internal service URLs (`aifactory.`, `cfactory.`,
    `cfactory-mcp.freundcloud.org.uk`) and how to read `factory-secrets`.
  - The other six contain only placeholders (`${…}`, `change-me`, `xxx`).
- **MCP wiring:** agent-bus MCP is configured for Claude and Codex
  (`~/.codex/config.toml`), not Antigravity.
- **Home Manager and Syncthing:**
  - `backupFileExtension` is not set, so HM aborts rather than overwrite a
    regular file.
  - `managedSkillIgnores` (`home/syncthing-stignore.nix`) already derives its
    ignore list from `config.home.file`.
  - The `syncthingIgnores` step runs `entryAfter [ "linkGeneration" ]`.
- **File mode:** `dns/scripts/dns.sh` is `100644` in git. HM currently sets
  `executable = true` on it.

## Design

All in `home/development/claude-code-skills/default.nix`. The current ~30
per-file `home.file` lines become one table of agent directories, one table of
skills, and one expression that expands them:

```nix
# Where each agent reads skills. One entry can serve two agents.
agentDirs = {
  claude = ".claude/skills";
  agents = ".agents/skills";   # Codex and Antigravity both read this
  codex = ".codex/skills";     # Codex only; for skills whose MCP only Codex has
};

# name = { src; to = [ agentDirs keys ]; }
localSkills = {
  gog               = { src = ./gog;               to = [ "claude" "agents" ]; };
  notebooklm        = { src = notebooklmTree;      to = [ "claude" "agents" ]; };
  artifact-workflow = { src = ./artifact-workflow; to = [ "claude" "agents" ]; }; # #1832
  dns               = { src = ./dns;               to = [ "claude" "agents" ]; };
  obsidian          = { src = ./obsidian;          to = [ "claude" "agents" ]; };
  "1password"       = { src = ./1password;         to = [ "claude" "agents" ]; };
  agent-bus         = { src = ./agent-bus;         to = [ "claude" "codex" ]; };  # no MCP in agy
  second-opinion    = { src = ./second-opinion;    to = [ "claude" ]; };  # #1831
  ask-ollama-cloud  = { src = ./ask-ollama-cloud;  to = [ "claude" ]; };  # #1928, #1929
  # moved in from ~/.claude/skills, all agents:
  nixos-standards, fides, backstage-patterns, linkedin-post, reddit-post,
  cosmic-ui-design-skill
};

home.file = lib.mkMerge (lib.mapAttrsToList (name: s:
  lib.genAttrs' s.to (a: lib.nameValuePair "${agentDirs.${a}}/${name}" {
    source = s.src;
    recursive = true;  # per-file links inside a real dir, as today
    force = true;      # replace the old regular files once
  })) localSkills);
```

- **`recursive = true`** keeps today's layout: a real directory holding
  per-file store links. Nothing takes over `~/.claude/skills` or its siblings,
  so nixarchy and nix-skills are left alone, which is what the per-file
  comment in the current file asks for.
- **`notebooklmTree`** is a `pkgs.runCommand` that copies `./notebooklm` and
  links `reference.md` and `references` from `nlmData`. The current
  store-path references, which follow the nightly package bump, are kept.
- **`dns.sh`** gets `git update-index --chmod=+x`, so the store copy stays
  executable without a per-file override.
- **Syncthing:** the step changes from `entryAfter [ "linkGeneration" ]` to
  `entryBefore`. The ignores are computed at eval time from `config.home.file`,
  so they don't depend on the links existing. Writing them first closes the
  window in which a host's new store symlinks look syncable. That window is
  the mechanism behind the dangling links fixed in #1960, and it would hit
  every skill this change moves.
- **Clean-up:** the `.codex/skills/{gog,notebooklm}` and
  `.gemini/skills/{gog,notebooklm}` entries are dropped. `.agents/skills`
  replaces the first; nothing reads the second.

**Not moved into the repo:**
- `parr-run` and `run-aws-demo` stay as they are. They describe private
  infrastructure, and this repo is public. The spec records them as known
  exceptions; they are not migrated.
- The 5 `skills`-CLI skills stay under that CLI. Its own `--agent` flag
  reaches other agents, and copying them in would fork third-party content.

## Alternatives rejected

- **Link whole skill directories** (no `recursive`). This is cleaner, but HM
  aborts on the existing real directories, and it reverses the per-file
  choice documented in the current file. Needs a manual `rm` on each host first.
- **Adopt nix-agency or add these to the public nix-skills repo.** That's a
  second deploy tool or a public repo for personal skills. The intent rules
  out new tools, and nix-skills is scoped to Nix-manual skills.
- **A private flake input for `parr-run` and `run-aws-demo`.** It's a new
  repo and input for two files. Deferred until more private skills exist.
- **Keep per-file lines and just add the missing ones.** That would roughly
  double the lines to about 60 hand-kept paths. It's exactly the duplication
  the intent is about.
- **Target Pi and `~/.gemini/skills`.** Neither is read by an installed agent.
  Add a row to `agentDirs` when one is.

## Risks

- **Duplicate skills in Antigravity.** nix-skills (#1958) already installs
  into both `.agents/skills` (as "codex") and `.gemini/config/skills`, both of
  which agy reads. This change adds no new duplicates, but it doesn't fix that
  one either. Follow-up for nix-skills: map codex and antigravity to one
  directory.
- **`force = true`** overwrites whatever is at those exact paths. The only
  things there are the files being moved, and each one is committed first.
- **Hosts rebuilt at different times.** Until razer and p510 rebuild, they
  keep their Syncthing copies of the six moved skills. That's harmless: once
  p620's ignore list excludes those names, Syncthing no longer syncs them from
  p620.
- **Codex and Antigravity load 11 or 12 more skills** than today. Skills load
  on demand by description, so the cost is the listing, not the bodies.

## Verification

1. `nix flake check` and
   `nix build .#nixosConfigurations.{p620,razer,p510}.config.system.build.toplevel`
   all pass.
2. After `switch` on p620:
   - `ls ~/.claude/skills ~/.agents/skills ~/.codex/skills` shows exactly the
     table.
   - `readlink ~/.agents/skills/gog/SKILL.md` points into the store.
   - `test -x ~/.claude/skills/dns/scripts/dns.sh` passes.
3. `~/.claude/.stignore` lists the six moved names, and Syncthing's
   `/rest/db/ignores?folder=claude-config` shows them.
4. `~/.codex/skills/gog` and `~/.gemini/skills/gog` are gone.
   `parr-run` and `run-aws-demo` are unchanged and still synced.
5. Codex and `agy` each list `artifact-workflow` and `nixos-standards` in a
   fresh session.
