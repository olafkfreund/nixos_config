# Feature Flags

## The problem

Enabling a capability often means configuring several services together. Doing
that inline in each host file produces copy-paste, drift, and no way to validate
that prerequisites are met.

## The solution

Capabilities are exposed as **typed feature flags** under `features.*`. A host
turns a dial; the module behind it wires up the actual services. The feature
system (`lib/features.nix`) additionally validates **dependencies** and
**conflicts** at evaluation time.

```nix
# In a host configuration.nix — declarative intent, not implementation
features = {
  development.enable = true;
  virtualization = {
    enable = true;
    docker = true;
  };
  ai.enable = true;
  media.enable = true;
  syncthing.enable = true;
};
```

## How a feature module is shaped

Every module follows the same contract: declare options, then apply config only
when enabled.

```nix
{ config, lib, pkgs, ... }:
let
  cfg = config.features.myservice;
in
{
  options.features.myservice = {
    enable = lib.mkEnableOption "MyService";
    port = lib.mkOption {
      type = lib.types.port;
      default = 8080;
      description = "Port MyService listens on.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.myservice = {
      enable = true;
      port = cfg.port;
    };
  };
}
```

!!! warning "Never configure services directly in a host"
    `services.foo = { … }` in `hosts/*/configuration.nix` defeats reuse and
    testing. Wrap it in a module under `modules/` and expose a feature flag.
    This is a hard rule — see [Anti-Patterns](../NIXOS-ANTI-PATTERNS.md).

## Dependency and conflict validation

`lib/features.nix` carries a small registry describing how features relate.
When a host enables a feature, the system asserts its dependencies are present
and that no conflicting feature is active:

```nix
development = {
  dependencies = [ "networking" ];
  conflicts = [ ];
  description = "Development environment setup";
};
gaming = {
  dependencies = [ "graphics" ];
  conflicts = [ "server-minimal" ];
};
```

If you enable a feature without its dependency, the build fails fast with a
clear message — far better than a service silently misbehaving at runtime.

## Feature profiles

Common bundles are pre-composed so a host can opt into a whole role at once:

| Profile | Enables |
| --- | --- |
| `workstation` | development, desktop, virtualization, security |
| `gaming` | desktop, gaming, security |
| `server` | virtualization, security, networking |
| `minimal` | security |

Explicit per-feature flags always take precedence over profile defaults.

## Browsing what exists

The full set of feature-flagged modules — every option, with its description
and the source — is in the generated [Modules reference](../reference/modules/index.md).
