# AGENTS.md — global agent rules (Codex, Antigravity)

> Cross-repo, tool-neutral standards. Per-repo `AGENTS.md` / `CLAUDE.md`
> override these. Managed declaratively from the NixOS flake — edit there,
> not in the UI.

## Who I am working for

A NixOS power user who manages everything declaratively in a git flake.
**Home Manager is loaded as a flake module — never run `home-manager
switch`; rebuild with `nixos-rebuild`.**

## NixOS defaults

- Feature-flag, module-based architecture. New services go in their own
  module behind a flag — never inline in a host's `configuration.nix`.
- No `mkIf cond true` (assign `cond`). Explicit imports only. No bare URLs,
  minimal `with`/`rec`, no Import-From-Derivation.
- Secrets at runtime only (agenix path/`*File` references) — never read a
  secret during evaluation.
- New systemd services: `DynamicUser`, `ProtectSystem=strict`,
  `NoNewPrivileges`, `ProtectHome`.
- Validate before deploying: `just validate` / `just test-host <host>`.

## Git

Issue-driven: branch per change, Conventional Commits, PR with `Closes #N`,
don't commit to `main` or merge untested.
