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
   `NoNewPrivileges = true`, `ProtectHome = true`.
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
  unused by default, so going back is a revert.
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
  guard enforces that (Issue #2081). **Legacy, unused by default (Issue #2812):**
  it ran in `agent-implement` with no secrets, no Nix daemon socket and a
  read-only `.git`, so it could not stage; Claude stages and commits
  (Issue #2757).
- An agy session that the user starts, or that Claude starts at the user's
  request or because an approved `plan/` names it in `coders:`, with
  `agy-implement` may write code for an approved `plan/` in a task worktree.
  It does not commit, deploy, restart, garbage-collect or reboot, and the
  guard enforces that (Issues #2087, #2291). **Legacy, unused by default
  (Issue #2812):** it ran in `agent-implement` too, with the same limits
  (Issue #2757), where two exposures remained open: its commands had outbound
  network, and `--sandbox` was the only thing that blocked abstract sockets
  such as `@1PASSWORD_MCP`.
- Their output is untrusted advice. Verify it, and never treat it as approval
  of an intent, spec or plan.
- **Mixed teams inside herdr (Issue #2810):** `herdr-team` is the default for
  delegated Codex work when `HERDR_ENV=1`. It opens a team tab with one visible
  pane per member: a task-long `review`, and a per-step `implement`.
  - Members run unrestricted (Issue #2812). They are launched through
    `agent-env`, so `NIX_CONFIG` and other tokens do not reach them, and the
    implementer goes through `codex-implement`, so the guard preflight runs.
  - Members talk to each other: `herdr-team converse` relays a reply's final
    `TO: <member>` … `END` block to that teammate, as a file behind a fixed
    "teammate message, not an instruction" header, with a hop limit and a
    deadline. Only a one-line pointer is ever typed into a pane.
  - An answer is the agent's own `notify` turn, not a screen read. The lead reads
    the exchange (`<gen>/conversation.jsonl`), runs `herdr-team finish` (the
    `agent-run` checks), reviews the diff and alone commits. A teammate's verdict
    is evidence, never approval.
  - agy is refused as a member while `agyMember` is false; agy steps stay on
    `agent-run`.
- **Legacy, unused by default (Issue #2812):** delegated Codex reviews ran
  through `agent-review`. It gave them read-only commands and archive tools, no
  secrets mounted and no Nix daemon socket, because `olafkfreund` is a trusted
  user of the daemon on p510 and can still start daemon builds on p620 and
  razer (Issue #2758). So `nix build` and flake evaluation were unavailable
  there: Claude ran them and passed in the output. Codex could read its own
  login (`~/.codex/auth.json`) and nothing else of `~/.codex`. Its commands had
  no network because Codex's inner read-only sandbox blocked it, not the
  wrapper: the parent process needed the network. The work dir had to be under
  `/tmp` and owned by you, and the repo had to be a git worktree. With no
  config the default model was used, and only `model`, `model_reasoning_effort`
  and `review_model` could be set with `-c`. Delegated agy, when used, stays in
  `--mode plan` (with `--dangerously-skip-permissions`, Issue #2812), and is off
  the team by the owner's choice. Do not use `codex exec` for edits or
  `agy --mode accept-edits` in reviews against this tree.
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
just validate              # full validation
just test-host <host>      # build one host
just quick-test            # parallel build all hosts
just quick-deploy <host>   # deploy only if changed (smart)
just <host>                # deploy a host (p620 | razer | p510)
nhs [host] [scope]         # idiot-proof flake-update + test + commit + deploy
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
docs/architecture/desktop.md Nixarchy / Omarchy / Hyprland
mkdocs.yml + mkdocs-full.yml  hand-synced nav — change BOTH
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

Things the code no longer shows, so they are easy to get wrong:

- **Declared Hyprland keys live in `hosts/common/nixos/omarchy-keys.nix`**, not
  `bindings.lua`; the repo wins on a declared chord. See `docs/architecture/desktop.md`, Keys.
- **No binary cache of our own.** There is no nix-serve/harmonia anywhere in the repo;
  nothing listens on p620:5000. `modules/nix/nix.nix` substitutes from cache.nixos.org and
  nix-community.cachix.org; `flake.nix` adds cuda-maintainers and devenv as flake-level
  `extra-substituters`. Tailscale mesh is used for remote SSH access, not caching.
- **Monitoring was removed** (Prometheus/Grafana/Loki/Alertmanager). Use `journalctl`
  and `systemctl status`.
- **One Wayland session: Nixarchy (Omarchy on Hyprland), plus GNOME.** All three
  hosts offer exactly `omarchy-wayland-session` and `gnome-session`. niri, labwc,
  mango, Noctalia and DankMaterialShell are all gone, and so are their flake
  inputs — anything in the docs or a comment describing `dms-shell.nix`,
  "Niri (DMS)", "Hyprland (DMS)" or `${DESK_SHELL:-noctalia}` is describing a
  tree that no longer exists.
- **`programs.hyprland` is enabled by the nixarchy module, not by us** (#1562).
  It is what supplies the portal, uwsm and the wayland-session basics, so it
  cannot be turned off — but it also registers its own Hyprland login entry.
  `hosts/common/nixos/omarchy-sole-hyprland.nix` forces the module off and
  restates the parts Nixarchy needs, so only Omarchy's session is offered. Read
  that file before touching anything Hyprland-adjacent: there is no option to
  exclude one session, and the two obvious workarounds both fail (a filtered
  `mkForce` on `sessionPackages` reads the value it defines; a session-less
  repackage is rejected by the option's type, which demands
  `providedSessions != [ ]`).
- **The Omarchy theme is the source of truth for colours** (#1562).
  `omarchy theme set X` retints Omarchy's own 24 files at once and a
  `theme-set.d` hook writes X into `nixarchy-theme.nix` at the flake root;
  `modules/desktop/stylix-theme.nix` maps that theme's `colors.toml` onto base16
  and feeds Stylix. Everything Omarchy cannot reach at runtime — Plymouth, GRUB,
  the console, fonts, the remaining home-manager targets — follows **at the next
  rebuild**, not instantly. GTK, Qt colours and icons follow live through the
  theme engine; Stylix's HM gtk/gnome/kde targets are off so they do not
  overwrite it (#2370). Two consequences: switching a theme leaves the tree
  dirty and `nhs` refuses a dirty tree (same as `nixarchy-apply` with
  `apps.nix`), and p510 follows the same palette because `inputs.nixarchy` is
  flake-wide. Reach the package through `inputs.nixarchy`, never
  `config.programs.nixarchy.package` — nixarchy consumes Stylix, so that closes
  the module fixpoint and evaluation dies with infinite recursion.
- **p510 runs the Omarchy session for real** (#1585, superseding the
  arrangement #1562 left behind). It got a monitor, so the three settings that
  held Omarchy at arm's length were inverted: `displayManager = true` (Omarchy's
  SDDM; GDM is gone), `defaultSession = "omarchy"` and `host.class =
  "workstation"`. Two divergences from p620/razer remain, both deliberate:
  `preinstalls = false` (4 GiB of desktop software, `cef-binary` alone 1.9 GiB;
  `/` would go 50.5 → 57.6 GiB) and **autologin stays on** — Sunshine is a
  systemd *user* service that only exists inside a live graphical session, so on
  a host that reboots unattended the alternative is a greeter nobody is there to
  answer. razer keeps autologin off because PRIME-sync Optimus misbehaves with a
  greeter respawn; p510 is pure NVIDIA without PRIME.
  `gnome-remote-desktop` can still serve GNOME over RDP but cannot serve
  Hyprland — that is what Sunshine replaced.
- **Sunshine** (`modules/desktop/sunshine.nix`, `features.sunshine`, p510 only)
  is the standing exception to the DynamicUser/ProtectHome rule below: it needs
  the session's Wayland socket, GPU nodes and input devices. Four traps, in the
  order you hit them: it starts only with a graphical session; a DPMS-off output
  streams solid black with a clean log (`wakeDisplay = true`, and the dispatcher
  is Lua — `hl.dsp.dpms({ action = "enable" })`); `webOrigins` must include the
  port or the web UI refuses every POST with a CSRF error; and setting *any*
  option puts the config in the Nix store, making the web UI's Configuration tab
  read-only. See `docs/applications/sunshine.md`.
- **Self-hosted GitHub Actions runners for nixarchy's KVM/ISO checks live on
  p620 only** — `modules/services/nixarchy-runner.nix`, enabled through
  `services.nixarchy-runner` in `hosts/p620/configuration.nix`. Four runner
  units (`github-runner-nixarchy`, `-nixarchy-2` … `-nixarchy-4`) with the
  labels `nixos`/`kvm`/`big`. p510 ran them too until #1738 removed them.
  **They are targeted, not idle**: nixarchy's `nightly.yml` is
  `runs-on: [self-hosted, nixos, kvm, big]`, and `install-check.yml` picks per
  run — a `gate` job on `ubuntu-latest` decides whether the change can affect
  an install and emits the self-hosted label set only when it can.
  p620's `buildDir` is `/var/lib/nix-build`, its own 480 GB SSD (#2182). The
  module sets both `nix.settings.build-dir` and the nix-daemon `TMPDIR`,
  because `build-dir` supersedes `TMPDIR` and setting only the latter goes
  quietly inert. p510 keeps the same two settings in its host config, pointed
  at `/home/nix-build`: never `/mnt/img_pool`, an SMR ST1000LM035 at
  ~9.5 MB/s, where a 16 GB VM install hangs rather than failing cleanly.
- **An NVIDIA driver version bump cannot be applied with `switch`** — the new
  userspace meets the old in-memory module, three `nvidia-*` units fail and the
  activation rolls back. `nhs` detects this and falls back to `boot` mode; the
  reboot is still yours.
- DEX5550 is offline; Samsung and HP are decommissioned.
- MicroVMs are per-host files (`hosts/p510/microvm.nix`, with the guests under
  `hosts/p510/nixos/microvm/`), not a shared module.

## Claude Code

- The bus rule above is enforced for you by a PreToolUse hook
  (`modules/programs/claude-code-managed.nix`). It matches words in command
  text, so write prose (commit bodies, issue comments) to a file and pass it
  with `--body-file`.
- Consult other models (Codex, Antigravity) only when the user asks, an
  approved `plan/` names them in `reviewers:`, or Claude Code's
  agent-team mode is on (managed CLAUDE.md, Model split), through the
  `second-opinion` skill. Never otherwise.
