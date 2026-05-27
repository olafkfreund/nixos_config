# Overlays

## The problem

Two recurring needs: packaging software that is not in nixpkgs (or is patched),
and fixing upstream packages without waiting for a nixpkgs release. Both require
modifying the package set — but a single monolithic overlay becomes an
unreadable grab-bag.

## The solution

Overlays are **split by purpose** under `overlays/`, so each file has one job:

| Overlay | Purpose |
| --- | --- |
| `default.nix` | Entry point — composes the others |
| `custom-packages.nix` | Wires in the ~60 packages from `pkgs/` |
| `upstream-fixes.nix` | Temporary patches for broken/lagging nixpkgs packages |
| `cmake-compat.nix` | CMake compatibility shims |
| `python-compat.nix` | Python packaging compatibility |
| `citrix-workspace.nix` | Citrix Workspace (needs a manual tarball) |

## Custom packages

The `pkgs/` tree holds packages built from source or vendored: MCP servers,
GNOME/COSMIC extensions, CLI tools, and desktop apps. `custom-packages.nix`
exposes them on `pkgs.*` so any module or host can reference them like any other
package.

Browse them all — name, version, description, and source — in the generated
[Custom Packages reference](../reference/packages.md).

## A real example: nix-prefetch-git regression

`nixpkgs-unstable` started naming the `nix-prefetch-git` binary
`nix-prefetch-git-<version>`, which broke `fetchCargoVendor` for any Rust
package with git dependencies. Rather than patch dozens of packages, a single
overlay restores the expected binary name via `postFixup`:

```nix
# Illustrative — adds a stable `nix-prefetch-git` symlink
nix-prefetch-git = prev.nix-prefetch-git.overrideAttrs (old: {
  postFixup = (old.postFixup or "") + ''
    ln -s $out/bin/nix-prefetch-git-* $out/bin/nix-prefetch-git
  '';
});
```

This is exactly what `upstream-fixes.nix` is for: contain the workaround in one
place, document why, and remove it when nixpkgs catches up.

## Why split overlays

- **Readability** — each file is small and single-purpose.
- **Lifecycle** — `upstream-fixes.nix` is meant to shrink over time; keeping it
  separate makes stale workarounds obvious.
- **Safety** — compatibility shims do not get tangled with first-party
  packaging.
