#!/usr/bin/env bash
# Bump pkgs/gogcli/default.nix to the latest openclaw/gogcli release.
#
# Modes:
#   ./scripts/update-gogcli.sh           # resolve latest, edit the derivation in place (idempotent)
#   ./scripts/update-gogcli.sh --check   # exit 0 if up-to-date, 1 if a bump is available; never edits
#
# Source of truth: the GitHub `releases/latest` endpoint for openclaw/gogcli.
# Unlike BrowserOS this repo publishes one tag series, so `releases/latest` is
# the right question to ask.
#
# This is the first Go package in the nightly autoupdate set, and it needs TWO
# hashes rather than one:
#
#   hash        the unpacked source tree. `nix flake prefetch github:owner/repo/TAG`
#               reports exactly what fetchFromGitHub expects -- verified against
#               the v0.19.0 pin, which it reproduced byte for byte. Do NOT use
#               `nix store prefetch-file` on the tarball URL: that hashes the
#               archive, while fetchFromGitHub hashes the extracted tree.
#
#   vendorHash  the Go module set. There is no way to compute this without
#               asking Nix to build it, so the only honest method is to write a
#               deliberately wrong hash, build, and read the "got:" line from
#               the mismatch. That is what the two-phase edit below does.
#
# The vendorHash phase needs the derivation reachable as a flake installable,
# and it is exposed by overlays/custom-packages.nix as a TOP-LEVEL pkgs.gogcli
# -- not under customPkgs. Getting that path wrong fails with "does not provide
# attribute" rather than anything about hashes.
#
# Because the vendorHash phase builds from the working tree, the edited file
# must be visible to Nix: git add it first if it is newly untracked, or the
# build resolves the committed content and the new vendorHash is computed
# against the OLD source.
#
# Wired into .github/workflows/package-autoupdate.yml for the nightly run.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
DRV="${ROOT_DIR}/pkgs/gogcli/default.nix"

# A hash that is valid SRI but cannot be right, to provoke the mismatch whose
# error message carries the real vendorHash.
FAKE_HASH="sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
INSTALLABLE=".#nixosConfigurations.p620.pkgs.gogcli"

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

for cmd in curl jq nix git; do
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

latest_version=$(
  api "https://api.github.com/repos/openclaw/gogcli/releases/latest" \
    | jq -r 'select(.prerelease == false) | .tag_name // empty' | sed 's/^v//'
)

[ -n "${latest_version}" ] || {
  echo "error: could not resolve the latest gogcli release" >&2
  exit 1
}

current_version=$(sed -nE 's/^[[:space:]]*version = "([^"]+)";.*/\1/p' "${DRV}" | head -1)
[ -n "${current_version}" ] || {
  echo "error: could not read the current version from ${DRV}" >&2
  exit 1
}

printf '  %-12s current=%s latest=%s\n' gogcli "${current_version}" "${latest_version}"

if [ "${current_version}" = "${latest_version}" ]; then
  [ "${CHECK_ONLY}" -eq 1 ] && echo "up-to-date" || echo "up-to-date; no changes written"
  exit 0
fi

if [ "${CHECK_ONLY}" -eq 1 ]; then
  echo "outdated: gogcli ${latest_version} is available"
  exit 1
fi

echo "    prefetching source for v${latest_version} ..."
src_hash=$(nix flake prefetch --json "github:openclaw/gogcli/v${latest_version}" | jq -r '.hash')
[ -n "${src_hash}" ] && [ "${src_hash}" != "null" ] || {
  echo "error: source prefetch failed for v${latest_version}" >&2
  exit 1
}

# Phase 1: version + source hash, with the vendorHash deliberately wrong.
tmp=$(mktemp)
sed -E \
  -e "s|^([[:space:]]*)version = \"[^\"]+\";|\1version = \"${latest_version}\";|" \
  -e "s|^([[:space:]]*)hash = \"[^\"]+\";|\1hash = \"${src_hash}\";|" \
  -e "s|^([[:space:]]*)vendorHash = \"[^\"]+\";|\1vendorHash = \"${FAKE_HASH}\";|" \
  "${DRV}" >"${tmp}"

for expected in "version = \"${latest_version}\";" "hash = \"${src_hash}\";" "vendorHash = \"${FAKE_HASH}\";"; do
  grep -q "${expected}" "${tmp}" || {
    echo "error: rewrite did not take (${expected}); ${DRV} left untouched" >&2
    rm -f "${tmp}"
    exit 1
  }
done

# Keep the original so a failed vendorHash discovery can restore it rather than
# leaving a derivation pinned to a hash that provokes a mismatch on every build.
backup=$(mktemp)
cp "${DRV}" "${backup}"
mv "${tmp}" "${DRV}"
chmod 644 "${DRV}"

restore() {
  cp "${backup}" "${DRV}"
  chmod 644 "${DRV}"
  rm -f "${backup}"
}

# Phase 2: provoke the mismatch and read the real vendorHash out of it.
echo "    resolving vendorHash ..."
build_log=$(mktemp)
if nix build --no-link "${INSTALLABLE}.goModules" >"${build_log}" 2>&1; then
  # Succeeding here means the fake hash was accepted, which cannot happen
  # unless Nix stopped verifying fixed-output derivations. Treat it as a bug
  # rather than silently shipping FAKE_HASH.
  echo "error: build with a deliberately wrong vendorHash SUCCEEDED; refusing to continue" >&2
  cat "${build_log}" >&2
  rm -f "${build_log}"
  restore
  exit 1
fi

vendor_hash=$(sed -nE 's/^[[:space:]]*got:[[:space:]]+(sha256-[A-Za-z0-9+/=]+)$/\1/p' "${build_log}" | head -1)
if [ -z "${vendor_hash}" ]; then
  echo "error: could not read the expected vendorHash from the build output" >&2
  tail -30 "${build_log}" >&2
  rm -f "${build_log}"
  restore
  exit 1
fi
rm -f "${build_log}"

tmp=$(mktemp)
sed -E "s|^([[:space:]]*)vendorHash = \"[^\"]+\";|\1vendorHash = \"${vendor_hash}\";|" \
  "${DRV}" >"${tmp}"
grep -q "vendorHash = \"${vendor_hash}\";" "${tmp}" || {
  echo "error: vendorHash rewrite did not take" >&2
  rm -f "${tmp}"
  restore
  exit 1
}
mv "${tmp}" "${DRV}"
chmod 644 "${DRV}"
rm -f "${backup}"

echo "wrote ${DRV} (${current_version} -> ${latest_version})"
echo "  src        ${src_hash}"
echo "  vendorHash ${vendor_hash}"
