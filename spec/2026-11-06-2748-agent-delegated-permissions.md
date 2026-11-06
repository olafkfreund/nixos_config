---
status: draft
issue: 2748
intent: intent/2026-11-06-2748-agent-delegated-permissions.md
---

# Spec: Let agy and Codex run needed commands under control

## Decisions carried from the intent

- Reviewers may run read-only commands, including archive tools, plus `nix eval` and
  `nix build`. No network for their commands.
- Reviewers write only to a temporary directory for that run, never the repo.
- Codex is widened only as far as this adds, and only where a need is shown.
- Secrets should be not visible at all, where practical, rather than deny-listed.

## What testing found on p620

| Probe | Result |
| ----- | ------ |
| `codex sandbox` as used today | **Can read `~/.ssh/id_ed25519`, `~/.config/gh/hosts.yml`, other tools' credentials, and `/run/agenix/api-openai`.** The session bus is visible. Network and repo writes are blocked |
| Real `codex exec -s read-only` inside an empty-home `bwrap` | Secrets hidden, `tar` and `nix eval` work, network and repo writes blocked, login still works |
| Real `agy --mode plan --sandbox` inside the same `bwrap` | Login works |
| agy session allow-rule with named commands, on compound commands | Denied, so named rules may not cover them |
| agy session allow-rule `command(*)` | Accepted, no denials. The model only planned, so running commands under it is **not proven** |

The first row is a live hole. Nothing Codex reads is stopped from going back to its
model. Fixing it does not depend on widening anything.

## Design

### 1. `agent-review`: one wrapper for both tools

Add `home/development/agent-review.sh`, packaged the way `agent-run` is:

```bash
agent-review <agy|codex> <work-dir> -- <tool arguments>
```

It starts the whole tool inside `bwrap`, so its file tools and MCP servers are
confined as well as its shell commands:

- **Default-deny home:** `--ro-bind / /`, then `--tmpfs "$HOME"`, then only that tool's
  own config directory: `~/.codex` or `~/.gemini`. Neither tool can see the other's
  credentials.
- **Hidden:** `/run/agenix.d` (the real target of `/run/agenix`) and `/run/user/$UID`,
  which removes the session bus and the keyring. `/tmp` is a fresh tmpfs.
- **Repo:** the current worktree read-only, plus the main `.git` read-only, because a
  worktree's git data lives there.
- **Writable:** only `<work-dir>`, which the caller creates and removes, and a tmpfs home.
- **Other processes:** `--unshare-pid` with a new `/proc`, so `/proc/<pid>/environ` of
  other processes cannot leak tokens.
- **Environment:** `--clearenv`, then an allow-list (`PATH`, `HOME`, `LANG`, `TERM`,
  `TMPDIR`, `NIX_*`), so tokens in the caller's environment do not come along.
- **p510:** on that host, also hide `/nix/var/nix/daemon-socket`, so a reviewer cannot
  start a build there. Reviews still run.

It fails closed. It refuses to start if `bwrap` fails, if the worktree is not a git
worktree, or if the arguments contain `--dangerously-skip-permissions`, a `--mode`
other than `plan`, `--gemini_dir` or a config-dir flag, a Codex sandbox other than
`read-only`, or `HUMANIZE_CODEX_BYPASS_SANDBOX` in its environment.

### 2. Codex

Run through `agent-review` with `-s read-only` or `sandbox_mode="read-only"`, as now.
Its own sandbox keeps blocking network and writes, and `bwrap` adds the hiding. Tested
together in the table above. No capability is added.

### 3. agy

Run through `agent-review` with `--mode plan --sandbox` and a session-only
`--settings` allow-rule, which is never saved to the synced `settings.json`.

- **Protect agy's own config:** `~/.gemini` must stay writable for logs and state, but
  `settings.json`, `config/` and `hooks` are mounted read-only over it. Otherwise a
  reviewer could widen its own permissions and Syncthing would carry that to every host.
- **Reviewer guard:** add an `AGY_REVIEWER=1` branch to
  `modules/programs/agy-guard-adapter.sh`, deny by default like the coder branch. It
  allows the read tools and `run_command` without `BypassSandbox`, allows writes only
  under `<work-dir>`, and denies everything else, including MCP tools.
- **Blocked command text:** the guard also denies commit, push, deploy, restart,
  garbage-collect and reboot commands, using the shared coder guard. This is a second
  layer: the read-only mounts already stop most of them from having any effect.

**Gate, because this is unproven.** The plan's first agy step runs a real probe with a
prompt that does not invite planning. It must show commands running, secrets hidden,
repo and config writes blocked, and network blocked:

| Probe result | What ships for agy |
| ------------- | ------------------ |
| Everything holds under `command(*)` | The wildcard rule, confined as above |
| Commands run, but agy's terminal has network | A named allow-list instead, adding `tar`, `nix eval`, `nix build`, `git` read commands, without `curl`, `ssh` or similar. A named list cannot truly stop network, so the report says so |
| agy will not run commands in plan mode | Stop and come back to you. **Do not reach for `--dangerously-skip-permissions`** |

### 4. Show what was refused

agy does not name a denied command, so the reviewer branch logs each call through the
existing `AGY_GUARD_LOG` to `<work-dir>/guard.log`, with the tool, decision, reason and
flattened command text. `agent-review` prints the denied lines after the run. If a
denial appears in `denied_actions` with no matching log line, it prints that a command
was refused by agy's own permission layer and could not be named.

The log can contain command text, so `<work-dir>` is removed with the review.

### 5. Rule text

- `AGENTS.md`, "Delegating to other models": delegated reviews go through
  `agent-review`. Keep the ban on `--dangerously-skip-permissions`,
  `HUMANIZE_CODEX_BYPASS_SANDBOX` and API keys. Replace "read-only modes only" with
  what is now allowed and what stays forbidden.
- `home/development/claude-code-skills/second-opinion/SKILL.md`: all command blocks use
  `agent-review`, and its "what this skill will not do" section matches.
- `home/development/agent-rules/agy-standards.md` and
  `docs/tooling/agy-coder-guard.md`: add the reviewer mode.

`agy-implement`, `codex-implement` and `handoff` are unchanged.

## Alternatives rejected

- **`--dangerously-skip-permissions` for reviews:** removes the prompt layer with
  nothing replacing it, and is unnecessary if a session allow-rule works.
- **Only widen the allow-list:** a "read-only" command can still read a key, and this
  leaves the Codex hole open.
- **Deny known secret paths in a hook:** only stops what it names. Also does not cover
  Codex, whose hooks are skipped silently if untrusted.
- **Change `HOME` only:** absolute paths such as `/run/agenix` and `/home/...` still work.
- **A VM or separate user per review:** stronger, but much slower and heavier than this
  needs.
- **Change `settings.json` permanently:** it syncs to all three hosts and would apply to
  every agy session, including ones you run yourself.

## Risks

- **Things that stay visible:** each tool can read its own login (`~/.codex/auth.json`
  or `~/.gemini/oauth_creds.json`), because it needs it. So a reviewer's model could see
  that provider's own token. Anything world-readable outside `$HOME` also stays visible,
  as does the repo, including its encrypted `.age` files.
- **`nix build` runs repo code:** builds run through the daemon, with `sandbox = relaxed`
  on p620, and fixed-output builds have network. A reviewer could send repo contents out
  that way. It is accepted because no secret is mounted and each provider is already sent the
  repo material it reviews. Builds also load the host, and `timeout` is the only limit.
- **Remote builds:** `builders` is empty on p620 and no `buildMachines` are declared. If
  that changes, the reach to p510 must be rechecked. SSH keys and the agent are hidden
  regardless.
- **Abstract sockets:** agy needs the network namespace, so abstract Unix sockets stay
  reachable from inside it. The plan checks what is listening.
- **Nested sandboxes:** `--unshare-pid` and `--clearenv` were not in the p620 tests, and
  agy's `--sandbox` re-executes itself in namespaces, so this must be retested. It may also
  fail on envfs remounts (#2298).
- **razer and p510 are untested:** `bwrap` behaviour there needs its own probe.
- **agy updates:** a renamed tool hits deny-by-default, so reviews fail visibly rather than
  open up. `agy-implement`'s version gate does not cover this, and the probe is rerun by hand
  after a bump.
- **Existing gap, not changed here:** `agy-implement` and `codex-implement` run without the
  empty home, so they may still see these secrets. That belongs in its own issue.

## Verification

1. `home/development/agent-review.test.sh`, in the style of the existing `.test.sh` files:
   each forbidden argument is refused, and a `bwrap` failure refuses to start.
2. Live probe for each tool on p620, recording each result, with `test -r` only and never
   printing a value:
   - Hidden: an agenix secret, `~/.ssh/id_ed25519`, `~/.config/gh/hosts.yml`, the other
     tool's login, the session bus, and another process's `/proc/<pid>/environ`.
   - Blocked: writing to the repo, `~/.gemini/settings.json` and `~/.gemini/config/`, and
     outbound network from a command.
   - Working: `tar`, `nix eval`, a small `nix build`, `git log`, and login.
3. A forbidden action check: commit, push, and `ssh p510` must all fail, and the failures
   must show up in the caller's output.
4. Repeat the review that failed: a prompt that needs `tar` on a `.tar.xz` completes through
   agy with a non-empty response and no `denied_actions`. If agy took the named-list route,
   `tar` must be on it.
5. A refused command is named in the caller's output, or reported as unnamed if agy's own
   layer refused it.
6. Repeat steps 1 and 2 on razer, and on p510 only when you agree. On p510, confirm a build
   fails while a review still runs.
