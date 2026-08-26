#!/usr/bin/env bash
# Bump pkgs/claude-desktop-beta to the latest Anthropic Linux release.
#
# Modes:
#   ./scripts/update-claude-desktop.sh           # resolve latest, edit default.nix in place
#   ./scripts/update-claude-desktop.sh --check   # exit 0 if current, 1 if a bump is available
#
# Source of truth is Anthropic's signed apt repository. The Packages index
# carries Version and SHA256 in the same stanza, so no separate prefetch is
# needed — fetchurl takes the hex sha256 from the index as-is.
#
# THE INDEX IS NOT SORTED. It holds every historical release in arbitrary
# order, so a top-down read picks whatever happens to be first: on
# 2026-08-26 that was 1.17180.0, over 11,000 versions BEHIND the pinned
# 1.28929.0. The build would have succeeded and silently downgraded the
# package by more than a year. `sort -V` is mandatory, not stylistic.
#
# Wired into .github/workflows/package-autoupdate.yml for the nightly run.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKG_FILE="$(cd "${SCRIPT_DIR}/.." && pwd)/pkgs/claude-desktop-beta/default.nix"
INDEX="https://downloads.claude.ai/claude-desktop/apt/stable/dists/stable/main/binary-amd64/Packages"

CHECK_ONLY=0
case "${1:-}" in
  --check) CHECK_ONLY=1 ;;
  "") ;;
  *)
    echo "usage: $0 [--check]" >&2
    exit 2
    ;;
esac

[ -f "${PKG_FILE}" ] || {
  echo "error: ${PKG_FILE} not found" >&2
  exit 1
}

for cmd in curl awk python3; do
  command -v "$cmd" >/dev/null || {
    echo "error: '$cmd' is required" >&2
    exit 1
  }
done

# Pair each Version with the SHA256 from the same stanza, then take the
# highest by version sort. See the header on why sort -V is load-bearing.
latest=$(curl -fsSL --max-time 30 "${INDEX}" \
  | awk '/^Version:/{v=$2} /^SHA256:/{if (v != "") print v, $2; v=""}' \
  | sort -V | tail -1)

[ -n "${latest}" ] || {
  echo "error: could not parse any version from ${INDEX}" >&2
  exit 1
}

latest_version="${latest%% *}"
latest_sha="${latest##* }"

# The version lives in a `let` block; the sha256 in the fetchurl src.
current_version=$(grep -m1 -oE 'version = "[^"]*"' "${PKG_FILE}" \
  | sed -E 's/version = "([^"]*)"/\1/')

printf '  claude-desktop  current=%s latest=%s\n' "${current_version}" "${latest_version}"

if [ "${current_version}" = "${latest_version}" ]; then
  [ "${CHECK_ONLY}" -eq 1 ] && echo "up-to-date" || echo "up-to-date; no changes written"
  exit 0
fi

if [ "${CHECK_ONLY}" -eq 1 ]; then
  echo "outdated: a newer claude-desktop release is available"
  exit 1
fi

python3 - "${PKG_FILE}" "${latest_version}" "${latest_sha}" <<'PY'
import re, sys
f, ver, sha = sys.argv[1:4]
s = open(f).read()
for pat, val in ((r'(\n  version = ")[^"]*(";)', ver),
                 (r'(sha256 = ")[^"]*(";)', sha)):
    s, n = re.subn(pat, lambda m: m.group(1) + val + m.group(2), s, count=1)
    if n != 1:
        sys.exit(f"rewrite failed for {f}: pattern {pat!r} matched {n} times")
open(f, 'w').write(s)
PY

echo "wrote ${PKG_FILE}: ${current_version} -> ${latest_version}"
