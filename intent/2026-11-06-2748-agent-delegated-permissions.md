---
status: draft
issue: 2748
author: olafkfreund
---

# Intent: Let agy and Codex run needed commands under control

## Problem

Reviews delegated to agy fail when agy needs a command outside its allow-list. In
headless mode it cannot ask, so the command is auto-denied. On 6 November 2026
that lost a whole review of the intent for #2746: `status` was `SUCCESS`,
`response` was empty, and `denied_actions` listed only `RunCommand`.

Three things make this worse:

- Home Manager declares 14 read-only commands
  (`home/development/antigravity-config.nix`, from #2471), and the live list on
  p620 is exactly those. Anything else fails.
- agy's output and logs do not name the denied command, so nobody can tell what
  was missing. It may have been `tar`, because that review's prompt pointed at a
  `.tar.xz`. A later review with its documents inline and no archive had no
  denials, which fits but does not prove it.
- `AGENTS.md` forbids `--dangerously-skip-permissions` for delegated use, so the
  error's own suggestion is not allowed, and no controlled middle option exists.

The owner has asked for this rule to change for both agy and Codex: they should
be able to do what they need during delegated work, with that access controlled.

Codex has not failed this way. Its review ran under `sandbox_mode="read-only"`
and could read what it needed. Whether it needs more is an open question below.

## Proposed outcome

- A delegated review that needs a permitted command outside today's 14 completes
  with a non-empty response and no `denied_actions`. A repeatable check shows this.
- When something is still refused, the caller's output names the command and the
  reason.
- The agents' limits are enforced by a mechanism, not only stated in a rule, and
  a repeatable check proves that it blocks each forbidden action in Constraints.
- `AGENTS.md`, the `second-opinion` skill and the tool configuration all describe
  the same rule.

## Affected users and systems

- agy and Codex when called by Claude Code, on p620, razer and p510. `~/.gemini`
  is synced across all three by Syncthing, so an agy settings change reaches them
  together. `~/.codex` is per host.
- `AGENTS.md`, `second-opinion`, possibly `handoff`,
  `home/development/antigravity-config.nix`, `home/development/codex-cli.nix`,
  `modules/programs/agy-guard-adapter.sh` and `docs/tooling/agy-coder-guard.md`.

## Constraints

These stay whatever the design is:

- Delegated agents never commit, push, deploy, restart a service, garbage-collect,
  reboot, or approve an artifact.
- Delegated agents never read decrypted secrets (`/run/agenix/*`, tokens, private
  keys). A "read-only" command can still read a secret, and a build can run code
  from the repo, so read-only alone does not satisfy this.
- p510 is never built without asking first, and that includes builds a delegated
  agent starts there.
- Subscription login only, never an API key (#1831).
- `HUMANIZE_CODEX_BYPASS_SANDBOX` stays forbidden.
- A control must fail closed. Two known traps: Codex silently skips untrusted
  hooks, and agy's hook payload differs from Claude's, so a guard used unchanged
  fails open.
- Their output remains untrusted advice.

## Open questions

1. **How far should "what they need" go for reviews?**
   - a. Reading only, with any read-only command, including archive tools.
   - b. Also evaluation and builds, such as `nix eval` and `nix build`, which write
     to the Nix store but not the repo.
   - c. Also network access, such as fetching upstream docs.

   Recommendation: a and b. Keep network off unless a review shows a need for it,
   because a reviewer that can read the repo and reach the network can leak it.
2. **May reviewers write anywhere?** Recommendation: only a per-run temporary
   directory, never the repo. Changing code stays with `agy-implement` and
   `codex-implement` under an approved plan.
3. **Should Codex change at all?** It has not failed, and `read-only` already lets
   it run commands. Recommendation: widen Codex only for what question 1 adds, and
   prove that need first rather than loosening it to match agy.
4. **How are secrets kept out when commands are wider?** A wider command list, a
   guard denying secret paths, and a sandbox each cover different things, and agy
   also has MCP tools outside the shell. Is it acceptable to rely on a deny list
   of known secret paths, or must reviewers run where those paths are not visible
   at all? Recommendation: not visible at all if the spec finds it practical,
   because a deny list only stops what it names.
