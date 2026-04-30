#!/usr/bin/env bash
# Bump pkgs/warp-terminal/versions.json to the latest stable Warp release.
#
# Modes:
#   ./scripts/update-warp-terminal.sh           # resolve latest, edit versions.json in place (idempotent)
#   ./scripts/update-warp-terminal.sh --check   # exit 0 if up-to-date, 1 if a bump is available; never edits
#
# Source-of-truth for versions: the redirect chain from
# https://app.warp.dev/download?package={pacman,pacman_arm64}, which 302s
# to a versioned URL on releases.warp.dev — same approach the upstream
# nixpkgs update.sh uses, and reliable for the past two years.
#
# Hashes: nix store prefetch-file --json | jq -r '.hash' (SRI-format).
#
# Wired into the derivation as passthru.updateScript. Typical workflow:
#   ./scripts/update-warp-terminal.sh && nhs p620   # bump + deploy

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
VERSIONS_JSON="${ROOT_DIR}/pkgs/warp-terminal/versions.json"

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

# Resolve `app.warp.dev/download?package=$1` → versioned releases.warp.dev URL.
# Walks up to 15 hops; mirrors upstream nixpkgs logic.
resolve_url() {
  local url="https://app.warp.dev/download?package=$1"
  local sfx="pkg.tar.zst"
  local i
  for ((i = 0; i < 15; i++)); do
    url=$(curl -fsS -o /dev/null -w '%{redirect_url}' "${url}" || true)
    [ -z "${url}" ] && {
      echo "error: empty redirect for package=$1" >&2
      return 1
    }
    [[ "${url}" == *."${sfx}" ]] && {
      echo "${url}"
      return 0
    }
  done
  echo "error: too many redirects for package=$1" >&2
  return 1
}

# Extract version from a .../v<VERSION>/... URL.
extract_version() {
  echo "$1" | grep -oE 'v[0-9]+\.[0-9]{4}\.[0-9]{2}\.[0-9]{2}\.[0-9]{2}\.[0-9]{2}\.stable_[0-9]+' | head -1 | sed 's/^v//'
}

# Compute SRI hash for a URL (no side effects on the working tree).
prefetch_sri() {
  nix store prefetch-file --json --hash-type sha256 "$1" 2>/dev/null | jq -r '.hash'
}

# pkg name → versions.json key
declare -A KEY_FOR_PKG=(
  [pacman]=linux_x86_64
  [pacman_arm64]=linux_aarch64
)

any_changes=0
tmp_json=$(mktemp)
cp "${VERSIONS_JSON}" "${tmp_json}"

for pkg in pacman pacman_arm64; do
  key="${KEY_FOR_PKG[$pkg]}"
  url=$(resolve_url "${pkg}")
  latest_version=$(extract_version "${url}")
  [ -z "${latest_version}" ] && {
    echo "error: could not parse version from ${url}" >&2
    exit 1
  }

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
  echo "outdated: a newer Warp release is available"
  exit 1
fi

if [ "${any_changes}" -eq 0 ]; then
  echo "up-to-date; no changes written"
  rm -f "${tmp_json}"
  exit 0
fi

mv "${tmp_json}" "${VERSIONS_JSON}"
echo "wrote ${VERSIONS_JSON}"
