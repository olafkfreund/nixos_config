#!/usr/bin/env bash
# Update the codex-bin package.
# Usage:
#   ./scripts/update-codex-bin.sh                   # prints current and latest
#   ./scripts/update-codex-bin.sh <version>|latest  # prints a Nix snippet
#   ./scripts/update-codex-bin.sh --write <version>|latest  # edit default.nix

set -u
# NB: intentionally no `set -e`; failures are handled explicitly with die.

PKG_FILE="$(dirname "$0")/../pkgs/codex-bin/default.nix"
BASE="https://github.com/openai/codex/releases/download"

die() {
  echo "error: $*" >&2
  exit 1
}
log() { echo ">> $*" >&2; }

latest_version() {
  # releases/latest excludes pre-releases; curl, not gh, because CI runs this without GH_TOKEN.
  local tag
  local auth=()
  [ -n "${GITHUB_TOKEN-}" ] && auth=(-H "Authorization: Bearer $GITHUB_TOKEN")
  tag=$(curl -fsSL --max-time 15 "${auth[@]}" https://api.github.com/repos/openai/codex/releases/latest | jq -er .tag_name) \
    || die "could not resolve latest release"
  echo "${tag#rust-v}"
}

prefetch_hash() {
  local url="$1" json
  if ! json=$(nix store prefetch-file --json --hash-type sha256 "$url" 2>&1); then
    log "prefetch failed for $url: $json"
    return 1
  fi
  printf '%s' "$json" | jq -r '.hash'
}

# Anchored on the platform key so the two hashes cannot be swapped.
rewrite_pkg() {
  python3 - "$@" <<'PY'
import re, sys
f, ver, x64, arm64 = sys.argv[1:5]
s = open(f).read()
subs = [
    (r'(\n  version = ")[^"]*(";)', ver),
    (r'(x86_64-linux = \{\s*target = "[^"]*";\s*hash = ")[^"]*(";)', x64),
    (r'(aarch64-linux = \{\s*target = "[^"]*";\s*hash = ")[^"]*(";)', arm64),
]
for pat, val in subs:
    s, n = re.subn(pat, lambda m: m.group(1) + val + m.group(2), s, count=1)
    if n != 1:
        sys.exit(f"rewrite failed for {f}: pattern {pat!r} matched {n} times")
open(f, 'w').write(s)
PY
}

WRITE=0
if [ "${1-}" = "--write" ]; then
  WRITE=1
  shift
fi

current=$(sed -nE 's/^[[:space:]]*version = "([^"]+)";.*$/\1/p' "$PKG_FILE" | head -1)

version="${1-}"
if [ -z "$version" ]; then
  echo "current = $current"
  echo "latest  = $(latest_version)"
  exit 0
fi
[ "$version" = latest ] && version=$(latest_version)

# Before prefetching, so a nightly no-op run downloads nothing.
if [ "$WRITE" -eq 1 ] && [ "$current" = "$version" ]; then
  echo "up-to-date at $version; no changes written"
  exit 0
fi

log "resolving hashes for $version ..."
url="$BASE/rust-v$version/codex-package"
x64_hash=$(prefetch_hash "$url-x86_64-unknown-linux-musl.tar.gz") \
  || die "could not hash x86_64 tarball for $version"
arm64_hash=$(prefetch_hash "$url-aarch64-unknown-linux-musl.tar.gz") \
  || die "could not hash aarch64 tarball for $version"

if [ "$WRITE" -eq 1 ]; then
  rewrite_pkg "$PKG_FILE" "$version" "$x64_hash" "$arm64_hash" \
    || die "could not rewrite $PKG_FILE"
  echo "wrote $PKG_FILE: $current -> $version"
  exit 0
fi

cat <<SNIP
Current pinned: $current
Target:         $version

Paste into $PKG_FILE:

  version = "$version";
  x86_64-linux hash  = "$x64_hash";
  aarch64-linux hash = "$arm64_hash";

Next:
  nix build .#codex-bin && result/bin/codex --version
SNIP
