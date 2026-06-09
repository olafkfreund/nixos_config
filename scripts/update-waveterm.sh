#!/usr/bin/env bash
# Bump pkgs/waveterm/versions.json to the latest stable WaveTerm release.
#
# Modes:
#   ./scripts/update-waveterm.sh           # resolve latest, edit versions.json in place (idempotent)
#   ./scripts/update-waveterm.sh --check   # exit 0 if up-to-date, 1 if a bump is available; never edits
#
# Source-of-truth for versions: GitHub Releases API latest endpoint, which
# always points to the most recent non-prerelease tag.
#
# Hashes: nix store prefetch-file --json | jq -r '.hash' (SRI-format).
#
# Wired into the derivation as passthru.updateScript. Typical workflow:
#   ./scripts/update-waveterm.sh && nhs p620   # bump + deploy

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
VERSIONS_JSON="${ROOT_DIR}/pkgs/waveterm/versions.json"

CHECK_ONLY=0
case "${1:-}" in
  --check) CHECK_ONLY=1 ;;
  "") ;;
  *)
    echo "usage: $0 [--check]" >&2
    exit 2
    ;;
esac

[ -f "${VERSIONS_JSON}" ] || {
  echo "error: ${VERSIONS_JSON} not found" >&2
  exit 1
}

for cmd in curl jq nix; do
  command -v "$cmd" >/dev/null || {
    echo "error: '$cmd' is required" >&2
    exit 1
  }
done

# Resolve latest stable release version from GitHub API.
latest_version=$(curl -fsSL "https://api.github.com/repos/wavetermdev/waveterm/releases/latest" \
  | jq -r '.tag_name | ltrimstr("v")')

[ -z "${latest_version}" ] && {
  echo "error: could not resolve latest version from GitHub API" >&2
  exit 1
}

# Compute SRI hash for a URL (no side effects on the working tree).
prefetch_sri() {
  nix store prefetch-file --json --hash-type sha256 "$1" 2>/dev/null | jq -r '.hash'
}

declare -A ARCH_FOR_KEY=(
  [linux_x86_64]=amd64
  [linux_aarch64]=arm64
)

any_changes=0
tmp_json=$(mktemp)
cp "${VERSIONS_JSON}" "${tmp_json}"

for key in linux_x86_64 linux_aarch64; do
  arch="${ARCH_FOR_KEY[$key]}"
  url="https://github.com/wavetermdev/waveterm/releases/download/v${latest_version}/waveterm-linux-${arch}-${latest_version}.deb"
  current_version=$(jq -r ".${key}.version" "${tmp_json}")

  printf '  %-15s current=%s latest=%s\n' "${key}" "${current_version}" "${latest_version}"

  if [ "${current_version}" = "${latest_version}" ]; then
    continue
  fi

  any_changes=1
  if [ "${CHECK_ONLY}" -eq 1 ]; then
    continue
  fi

  echo "    prefetching ${url} ..."
  hash=$(prefetch_sri "${url}")
  [ -z "${hash}" ] && {
    echo "error: prefetch failed for ${url}" >&2
    exit 1
  }

  jq --arg v "${latest_version}" --arg h "${hash}" \
    ".${key}.version = \$v | .${key}.hash = \$h" \
    "${tmp_json}" >"${tmp_json}.new" && mv "${tmp_json}.new" "${tmp_json}"
done

if [ "${CHECK_ONLY}" -eq 1 ]; then
  if [ "${any_changes}" -eq 0 ]; then
    echo "up-to-date"
    exit 0
  fi
  echo "outdated: a newer WaveTerm release is available"
  exit 1
fi

if [ "${any_changes}" -eq 0 ]; then
  echo "up-to-date; no changes written"
  rm -f "${tmp_json}"
  exit 0
fi

mv "${tmp_json}" "${VERSIONS_JSON}"
echo "wrote ${VERSIONS_JSON}"
