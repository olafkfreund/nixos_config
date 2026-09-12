#!/usr/bin/env bash
# Bump pkgs/browseros/default.nix to the latest BrowserOS browser release.
#
# Modes:
#   ./scripts/update-browseros.sh           # resolve latest, edit the derivation in place (idempotent)
#   ./scripts/update-browseros.sh --check   # exit 0 if up-to-date, 1 if a bump is available; never edits
#
# Source of truth: the GitHub releases list for browseros-ai/BrowserOS.
#
# The one trap here, and the reason this cannot be a one-line `releases/latest`
# call: that repo publishes THREE tag series into the same release list --
# `v0.50.3` (the browser), `ext-agent/v0.0.156.0` and `agent-server/v0.0.164`.
# The agent series ship most days and the browser every few weeks, so the
# newest release is almost never the browser: on 2026-09-12 `releases[0]` was
# ext-agent/v0.0.156.0 while the browser sat at v0.50.3, five days old. Hence
# the `^v[0-9]` filter below. `releases/latest` is wrong for a second reason
# as well -- it would answer with whichever series published last.
#
# Hashes: nix store prefetch-file --json | jq -r '.hash' (SRI-format).
#
# Wired into the derivation as passthru.updateScript, and run nightly by
# .github/workflows/package-autoupdate.yml.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
DRV="${ROOT_DIR}/pkgs/browseros/default.nix"

CHECK_ONLY=0
case "${1:-}" in
  --check) CHECK_ONLY=1 ;;
  "") ;;
  *)
    echo "usage: $0 [--check]" >&2
    exit 2
    ;;
esac

[ -f "${DRV}" ] || {
  echo "error: ${DRV} not found" >&2
  exit 1
}

for cmd in curl jq nix; do
  command -v "$cmd" >/dev/null || {
    echo "error: '$cmd' is required" >&2
    exit 1
  }
done

api() {
  # GITHUB_TOKEN lifts the 60/hour anonymous rate limit in CI; optional locally.
  if [ -n "${GITHUB_TOKEN:-}" ]; then
    curl -fsSL -H "Authorization: Bearer ${GITHUB_TOKEN}" "$@"
  else
    curl -fsSL "$@"
  fi
}

# Newest browser release. Sorting is GitHub's (publish order, newest first),
# so the first entry matching the browser tag shape is the one we want. Fetch
# once and keep the release object: its asset list is also how the AppImage is
# confirmed to exist, below.
releases_json=$(mktemp)
trap 'rm -f "${releases_json}"' EXIT
api "https://api.github.com/repos/browseros-ai/BrowserOS/releases?per_page=100" >"${releases_json}"

latest_release=$(
  jq -c '[.[] | select(.prerelease == false) | select(.tag_name | test("^v[0-9]"))][0] // empty' \
    "${releases_json}"
)
latest_version=$(printf '%s' "${latest_release}" | jq -r '.tag_name // empty' | sed 's/^v//')

[ -n "${latest_version}" ] || {
  echo "error: no browser release found (only ext-agent/agent-server tags?)" >&2
  exit 1
}

current_version=$(sed -nE 's/^[[:space:]]*version = "([^"]+)";.*/\1/p' "${DRV}" | head -1)
[ -n "${current_version}" ] || {
  echo "error: could not read the current version from ${DRV}" >&2
  exit 1
}

printf '  %-12s current=%s latest=%s\n' browseros "${current_version}" "${latest_version}"

if [ "${current_version}" = "${latest_version}" ]; then
  [ "${CHECK_ONLY}" -eq 1 ] && echo "up-to-date" || echo "up-to-date; no changes written"
  exit 0
fi

if [ "${CHECK_ONLY}" -eq 1 ]; then
  echo "outdated: BrowserOS ${latest_version} is available"
  exit 1
fi

url="https://github.com/browseros-ai/BrowserOS/releases/download/v${latest_version}/BrowserOS_v${latest_version}_x64.AppImage"

# Fail before editing if the asset is missing: a release can be tagged with the
# macOS and Windows artefacts uploaded and the AppImage still building, and
# rewriting the derivation then leaves a version that cannot be fetched.
#
# Asked of the API rather than with a HEAD on ${url}: that download URL
# redirects to objects.githubusercontent.com, which rejects GitHub's own
# Authorization header with 401. A token is always set in CI, so a HEAD check
# through api() would have failed on every run and the nightly bump would
# never have fired -- while the anonymous local run passed.
asset_name="BrowserOS_v${latest_version}_x64.AppImage"
printf '%s' "${latest_release}" \
  | jq -e --arg n "${asset_name}" '[.assets[].name] | index($n)' >/dev/null || {
  echo "error: release v${latest_version} has no ${asset_name} yet" >&2
  exit 1
}

echo "    prefetching ${url} ..."
hash=$(nix store prefetch-file --json --hash-type sha256 "${url}" | jq -r '.hash')
[ -n "${hash}" ] && [ "${hash}" != "null" ] || {
  echo "error: prefetch failed for ${url}" >&2
  exit 1
}

tmp=$(mktemp)
sed -E \
  -e "s|^([[:space:]]*)version = \"[^\"]+\";|\1version = \"${latest_version}\";|" \
  -e "s|^([[:space:]]*)hash = \"[^\"]+\";|\1hash = \"${hash}\";|" \
  "${DRV}" >"${tmp}"

# Both lines must have moved. A silent no-op edit is how a bump script starts
# reporting success while pinning the old build forever.
if ! grep -q "version = \"${latest_version}\";" "${tmp}" || ! grep -q "hash = \"${hash}\";" "${tmp}"; then
  echo "error: rewrite did not take; ${DRV} left untouched" >&2
  rm -f "${tmp}"
  exit 1
fi

mv "${tmp}" "${DRV}"
chmod 644 "${DRV}"
echo "wrote ${DRV} (${current_version} -> ${latest_version})"
