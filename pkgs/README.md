# Custom Packages

Packages that are not in nixpkgs or need changes from the nixpkgs version.
Each directory holds one package; `ls pkgs/` is the list.

## Registration

There are two ways a package becomes visible:

- `pkgs/default.nix` lists the package. `overlays/default.nix` exposes that
  set as `pkgs.customPkgs.<name>`.
- `overlays/custom-packages.nix` adds some packages at the top level as
  `pkgs.<name>` (and replaces `codex` and `claude-code`). Use this when
  other modules or nixpkgs expect the plain name.

A package can be in either place. Check both before you look for one.

## Adding a package

1. Create `pkgs/<name>/default.nix`.
2. Add it to `pkgs/default.nix`, and to `overlays/custom-packages.nix` if it
   must be top level.
3. Reference it as `pkgs.customPkgs.<name>` or `pkgs.<name>`.
