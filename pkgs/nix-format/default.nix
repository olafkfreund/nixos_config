# Formats .nix files with the repo's own formatter: the enclosing flake's
# `formatter.<system>` output if it has one, nixfmt otherwise. Shared by the
# Claude Code and Codex post-edit hooks and nixd's formatting.command (#1983).
# Never fails, so a hook cannot break the tool that triggered it.
{ writeShellApplication
, nix
, nixfmt
, coreutils
, stdenv
}:
writeShellApplication {
  name = "nix-format";
  runtimeInputs = [ nix nixfmt coreutils ];
  text = ''
    system=${stdenv.hostPlatform.system}

    flake_root() {
      local d="$1"
      while [ "$d" != "/" ]; do
        [ -f "$d/flake.nix" ] && { echo "$d"; return; }
        d="$(dirname "$d")"
      done
    }

    # format FILE CONTEXT_DIR
    format() {
      local root
      root="$(flake_root "$2")"
      if [ -n "$root" ] && timeout 30 nix eval "$root#formatter.$system" --apply 'x: true' >/dev/null 2>&1; then
        (cd "$root" && timeout 30 nix fmt -- "$1") >/dev/null 2>&1
      else
        timeout 30 nixfmt "$1" >/dev/null 2>&1
      fi
    }

    if [ "''${1:-}" = "--stdin" ]; then
      tmp="$(mktemp --suffix .nix)"
      trap 'rm -f "$tmp"' EXIT
      cat >"$tmp"
      orig="$(cat "$tmp")"
      # On failure print the input untouched rather than an empty buffer.
      if format "$tmp" "$PWD"; then cat "$tmp"; else printf '%s\n' "$orig"; fi
      exit 0
    fi

    for f in "$@"; do
      case "$f" in *.nix) ;; *) continue ;; esac
      [ -f "$f" ] || continue
      abs="$(realpath "$f")"
      format "$abs" "$(dirname "$abs")" || true
    done
    exit 0
  '';
}
