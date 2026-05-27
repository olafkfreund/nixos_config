# Philosophy & Why

The configuration is opinionated. These principles explain the trade-offs, so
that future changes stay coherent with the existing design.

## 1. Explicit over magic

**Why.** Auto-discovery (`readDir` + dynamic imports) saves a few lines but
hides *what actually loads*. When something breaks, you want to read one import
list, not trace a directory walk.

The template imports the module tree by hand. The cost is a visible list; the
benefit is that the list **is** the documentation of what is active.

```nix
imports = [
  ../../modules/core.nix
  ../../modules/development.nix
  ../../modules/desktop.nix
  # … explicit, greppable, obvious
];
```

## 2. Thin hosts, reusable modules

**Why.** Three machines sharing 90%+ of their configuration should not copy it
three times. Duplication drifts; abstraction stays in sync.

A host file declares feature flags and the handful of things that are genuinely
unique (GPU, monitors, host-specific services). Everything reusable lives in
`modules/`. Shared constants (user, locale, network) live in
`hosts/common/shared-variables.nix`.

## 3. Trust the module system

**Why.** NixOS already ignores disabled services. Wrapping enablement in
`mkIf cond true` adds evaluation overhead and obscures intent.

```nix
# Anti-pattern — never do this
services.foo.enable = mkIf cfg.enable true;

# Correct — direct boolean
services.foo.enable = cfg.enable;
```

This rule is enforced repo-wide. See [Anti-Patterns](../NIXOS-ANTI-PATTERNS.md).

## 4. Security by default

**Why.** A daemon that runs as root with full filesystem access is a liability,
even at home.

- Services run unprivileged (`DynamicUser`, `ProtectSystem`) where the upstream
  module allows it.
- Secrets are **never** read during evaluation (which would copy them into the
  world-readable Nix store). They are decrypted at runtime by agenix. See
  [Secrets](secrets.md).
- The local firewall is intentionally delegated to Tailscale's trust model on
  these hosts; access is gated at the mesh layer.

## 5. Reproducibility end to end

**Why.** "Works on my machine" is unacceptable for infrastructure.

- `flake.lock` pins every input.
- Binary caches (including a local `nix-serve` on p620) keep builds fast.
- Even this documentation builds reproducibly via `nix build .#docs`, so the
  published site is a deterministic function of the source.

## 6. Keep changes small and reversible

**Why.** NixOS generations make rollback trivial — but only if a change is
scoped tightly enough to reason about.

Prefer one feature flag, one module, one host at a time. Validate
(`just validate`), build (`just test-host`), then switch. If it misbehaves,
`nixos-rebuild switch --rollback`.

---

These principles are not aspirational — they are reflected throughout the
[Best Practices](../PATTERNS.md) and enforced in the
[Anti-Patterns](../NIXOS-ANTI-PATTERNS.md) checklist.
