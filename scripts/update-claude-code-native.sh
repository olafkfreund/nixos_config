#!/usr/bin/env bash
# Update claude-code-native package to a given version.
# Usage:
#   ./scripts/update-claude-code-native.sh            # prints channels, does nothing
#   ./scripts/update-claude-code-native.sh <version>  # prints Nix snippet for that version
#   ./scripts/update-claude-code-native.sh latest     # resolves and uses the /latest channel
#   ./scripts/update-claude-code-native.sh stable     # resolves and uses the /stable channel
#
# Read-only: prints version + hashes. Does NOT edit default.nix — paste the
# output yourself or pipe through sed.

set -u
# NB: intentionally no `set -e` — curl on a miss should not abort the whole
# script; we handle failure explicitly. Also no `pipefail` — jq-less is fine.

GCS="https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases"
PKG_FILE="$(dirname "$0")/../pkgs/claude-code-native/default.nix"

die() {
  echo "error: $*" >&2
  exit 1
}
log() { echo ">> $*" >&2; }

resolve_channel() {
  local ch="$1"
  curl -fsSL --max-time 10 "$GCS/$ch" 2>/dev/null \
    || die "could not resolve channel '$ch' (404 or network)"
}

prefetch_hash() {
  # Returns SRI hash, or empty string on failure (stderr shows why).
  local url="$1" platform="$2"
  local json
  if ! json=$(nix store prefetch-file --json --hash-type sha256 "$url" 2>&1); then
    log "prefetch failed for $platform: $json"
    return 1
  fi
  printf '%s' "$json" | jq -r '.hash' 2>/dev/null \
    || {
      log "jq failed parsing prefetch output for $platform"
      return 1
    }
}

# Banner + channel summary (always, for context).
echo "Channels:"
echo "  stable  = $(resolve_channel stable)"
echo "  latest  = $(resolve_channel latest)"
echo

version="${1-}"
if [ -z "$version" ]; then
  log "no version given. Rerun with a version number, 'latest', or 'stable'."
  exit 0
fi

# Shorthand: `latest` / `stable` → resolve to actual version.
case "$version" in
  latest | stable) version=$(resolve_channel "$version") ;;
esac

log "resolving hashes for $version ..."

x64_hash=$(prefetch_hash "$GCS/$version/linux-x64/claude" x86_64-linux) \
  || die "could not hash linux-x64 binary for $version"
arm64_hash=$(prefetch_hash "$GCS/$version/linux-arm64/claude" aarch64-linux) \
  || die "could not hash linux-arm64 binary for $version"

current=$(sed -nE 's/^[[:space:]]*version = "([^"]+)";.*$/\1/p' "$PKG_FILE" | head -1)

cat <<EOF
Current pinned: $current
Target:         $version

Paste into $PKG_FILE:

  version = "$version";
  ...
  sources = {
    x86_64-linux = {
      url = "\${gcs_bucket}/\${version}/linux-x64/claude";
      hash = "$x64_hash";
    };
    aarch64-linux = {
      url = "\${gcs_bucket}/\${version}/linux-arm64/claude";
      hash = "$arm64_hash";
    };
  };

Next:
  nix build .#claude-code-native && result/bin/claude --version
EOF
