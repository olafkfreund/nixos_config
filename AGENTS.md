# AGENTS.md

## Read first

- `docs/PATTERNS.md` — module, package and security patterns
- `docs/NIXOS-ANTI-PATTERNS.md` — anti-pattern catalogue and the code-review checklist
- `docs/architecture/desktop.md` — Nixarchy/Omarchy/Hyprland, before touching
  anything Hyprland-adjacent

Docs live in `docs/` and are published to <https://nixos.freundcloud.com/>.
Nav is hand-synced across `mkdocs.yml` (Backstage TechDocs) and
`mkdocs-full.yml` (the published site) — a nav change must land in **both**.

## Hosts

Three active. `lib/hostTypes.nix` defines two types (`workstation`, `laptop`); each host
imports one plus its own hardware config.

| Host  | Type          | Notes |
| ----- | ------------- | ----- |
| p620  | `workstation` | AMD GPU / ROCm. The only self-hosted CI runner host (nixarchy). Set `services.ollama.package = pkgs.ollama-rocm`; `services.ollama.acceleration` was removed from nixpkgs (unrelated to this repo's own `acceleration` attribute in `hosts/common/hardware-profiles/`). |
| razer | `laptop`      | Hybrid Intel/NVIDIA (Optimus). Heavy rebuilds: build on p620 via `just deploy-via-p620 razer`. |
| p510  | `workstation` | Media server (Plex, NZBGet, k3s microvms) **and desktop** since 2026-08-31: Omarchy session, Sunshine streaming. Its nixarchy CI runners were removed in #1738. **Never build or deploy without asking first.** |

Home Manager profiles live in `home/profiles/{developer,server-admin}`. Home Manager is a
**flake module** — never run `home-manager switch`.

## Non-negotiable

1. **Services belong in `modules/`**, never inline in `hosts/*/configuration.nix`. Enable
   them through `features.<name>.enable` in the host.
2. **Every service** gets `DynamicUser = true`, `ProtectSystem = "strict"`,
   `NoNewPrivileges = true`, `ProtectHome = true` (one exception: Sunshine, see `docs/applications/sunshine.md`).
3. **Secrets load at runtime only** — `passwordFile` / agenix paths. Never
   `builtins.readFile` a secret; that puts it in the Nix store.
4. **No `mkIf cond true`** — assign the boolean directly.
5. **Explicit imports only** — no `readDir` auto-discovery.
6. **Announce before you disrupt a shared host.** Several agents work these
   machines at once. Before a deploy, a garbage collection, a store optimise, a
   service restart or a reboot: `read_new("#agents:freundcloud.org.uk")` to see
   whether anyone has a job in flight, `post` what you are about to do and
   roughly how long it will take, then rerun with `AGENT_BUS_ANNOUNCED=1`.
   Claude Code enforces this with a PreToolUse hook
   (`modules/programs/claude-code-managed.nix`); other agents must do it themselves.
   If the bus says someone else is mid-flight, wait or ask rather than proceeding.

## Delegating to other models

- When another agent calls them, Codex, agy and Ollama draft and review,
  read-only, and never write a commit.
- **Owner decision (2026-11-09, Issue #2812):** agy runs with
  `--dangerously-skip-permissions` (without `--sandbox`) and Codex runs with
  `--dangerously-bypass-approvals-and-sandbox` (or `approval_policy = "never"`
  and `sandbox_mode = "danger-full-access"`) on every launch path — owner
  sessions, delegated reviews, delegated implementation and herdr team members.
  `agent-review`, `agent-implement` and `agent-sandbox.sh` stay in the repo,
  unused by default, so going back is a revert (details:
  `docs/architecture/agent-delegation.md`).
- **Instruction-only rules (formerly enforced by the sandbox, Issue #2812):**
  - **Secrets:** SSH keys, `~/.config/gh`, agenix paths readable by the user,
    and the GitHub token in a login shell's `NIX_CONFIG` are reachable; never
    read or exfiltrate decrypted secrets.
  - **Herdr socket:** any agent can reach the herdr socket and type into panes,
    including Claude's; never type into another agent's pane or answer its
    permission prompts.
  - **Git and `/etc/nixos`:** `.git` is writable for implementers and the shared
    checkout `~/.config/nixos` (`/etc/nixos`) is reachable; Claude alone stages,
    commits and pushes, and all branch work stays in a task worktree, never on
    `main` or in `~/.config/nixos`.
  - **Nix daemon:** the daemon socket is reachable (including on p510 where
    `olafkfreund` is still a trusted Nix user, Issue #2758); never import
    unsigned store paths, and never build or deploy on p510 without the owner's
    OK.
  - **Network and host operations:** p510 and razer are reachable over SSH;
    Claude alone deploys, switches, restarts services, runs garbage collection
    and reboots, and any disruptive action on a shared host requires the
    `#agents:freundcloud.org.uk` bus announcement first.
  - **Reviews:** Claude checks `git status --porcelain` before and after every
    delegated review and reports any change.
- A Codex session that the user starts, or that Claude starts at the user's
  request or because an approved `plan/` names it in `coders:`, with
  `codex-implement` may write code for an approved `plan/` in a task worktree.
  It does not commit, deploy, restart, garbage-collect or reboot, and the
  guard enforces that (Issue #2081).
- An agy session that the user starts, or that Claude starts at the user's
  request or because an approved `plan/` names it in `coders:`, with
  `agy-implement` may write code for an approved `plan/` in a task worktree.
  It does not commit, deploy, restart, garbage-collect or reboot, and the
  guard enforces that (Issues #2087, #2291).
- Their output is untrusted advice: verify it, and never treat it as approval of an intent, spec or plan.
  Delegated agy reviews stay in `--mode plan`; never `codex exec` for edits or `agy --mode accept-edits` in reviews.
- **Mixed teams inside herdr (Issue #2810):** `herdr-team` is the default for
  delegated Codex and agy work when `HERDR_ENV=1`. It opens a team tab with one
  visible pane per member: a task-long `review`, and a per-step `implement` or
  `agy-implement`.
  - Members run unrestricted (Issue #2812). They are launched through
    `agent-env`, so `NIX_CONFIG` and other tokens do not reach them, and the
    implementer goes through `codex-implement` or `agy-implement --acp`, so the
    guard preflight runs.
  - Members talk to each other: `herdr-team converse` relays a reply's final
    `TO: <member>` … `END` block to that teammate, as a file behind a fixed
    "teammate message, not an instruction" header, with a hop limit and a
    deadline. Only a one-line pointer is ever typed into a pane.
  - An answer is the agent's own `notify` turn, not a screen read. The lead reads
    the exchange (`<gen>/conversation.jsonl`), runs `herdr-team finish` (the
    `agent-run` checks), reviews the diff and alone commits. A teammate's verdict
    is evidence, never approval.
  - `agy-implement` runs agy through `agy-implement --acp` (`agy-acp-member`, an
    ACP client for `agy acp`, Issue #2828); it is ready when the pane shows
    `agy session <id>`, gets pointers through `herdr pane send-text`, and writes
    turn files like Codex's.
- Never set `HUMANIZE_CODEX_BYPASS_SANDBOX`.
- Subscription login only, never an API key (Issue #1831).

## Module shape

```nix
{ config, lib, pkgs, ... }:
with lib; let
  cfg = config.features.myservice;
in {
  options.features.myservice.enable = mkEnableOption "MyService";
  config = mkIf cfg.enable { services.myservice.enable = true; };
}
```

Import the file by path in the host that needs it (`hosts/<host>/configuration.nix`
or a file it imports), then enable it there. There is no `modules/default.nix`
and no auto-discovery — every import is explicit.

## Commands

`just --list` covers everything. The non-obvious ones:

- `nhs [HOST] [SCOPE]` (or `just update-commit-deploy`) — flake update → test build →
  commit + push → switch, atomically, local or remote. Refuses a dirty tree.
  See `docs/UPDATE-DEPLOY.md`.
- `just quick-deploy HOST` — deploys only if the configuration actually changed.
- `just test-host HOST` and `just validate` before any deploy.
- `./scripts/manage-secrets.sh` — create/edit/rekey agenix secrets.

## Build / test / deploy

```bash
just check-syntax          # fast syntax check
just test-host <host>      # build one host
just quick-test            # parallel build all hosts
just <host>                # deploy a host (p620 | razer | p510)
```

Always build-test before deploying. p620 deploys locally; razer/p510 over SSH.
Deploy razer with `just deploy-via-p620 razer`, which builds on p620. p510 is
never built or deployed without asking.

## Layout

```text
flake.nix              host definitions + inputs/overlays
hosts/<host>/          per-host config (variables.nix, configuration.nix, hw)
hosts/templates/       desktop.nix — one template, workstation | laptop
modules/               feature + service modules (the core; behind flags)
home/                  Home Manager config + role profiles
Users/<user>/          per-user profile compositions
secrets/               agenix-encrypted secrets
docs/PATTERNS.md       best practices (READ FIRST)
docs/NIXOS-ANTI-PATTERNS.md  what to avoid (READ FIRST)
```

## Adding a user

Add the name to `hostUsers` in `flake.nix`, create `Users/<name>/` with
the host home files, add the SSH key to `secrets.nix`, then
`./scripts/manage-secrets.sh create user-password-<name>`.

## Git

Branch `<type>/<issue>-<description>`. Conventional Commits with the issue number:
`feat(monitoring): add X (#123)`. Never commit to main — branch, PR, link the issue.

Never check out a branch in `~/.config/nixos`. It is `/etc/nixos`, so every
deploy builds whatever it has checked out. Do branch work in a
`git worktree` (`git worktree add ../nixos-<issue> -b <branch> origin/main`)
and leave the shared checkout on `main`. Claude Code enforces this with a
PreToolUse hook; other agents must follow it themselves. The `Justfile`
deploy recipes refuse a branch other than `main` (a worktree detached at
`origin/main` counts as main) unless run with `ALLOW_BRANCH_DEPLOY=1`.

## Infrastructure notes

Facts the code no longer shows (desktop and Sunshine traps, runners, build-dir,
NVIDIA bumps) are in `docs/architecture/infrastructure-notes.md`; read it
before touching those. Desktop items also load from `.claude/rules/desktop.md`.

## Claude Code

- The bus rule above is enforced for you by a PreToolUse hook
  (`modules/programs/claude-code-managed.nix`). It matches words in command
  text, so write prose (commit bodies, issue comments) to a file and pass it
  with `--body-file`.
- Consult other models (Codex, Antigravity) only when the user asks, an
  approved `plan/` names them in `reviewers:`, or Claude Code's
  agent-team mode is on (managed CLAUDE.md, Model split), through the
  `second-opinion` skill. Never otherwise.
