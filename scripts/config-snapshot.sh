#!/usr/bin/env bash
# config-snapshot.sh — prove a refactor changes nothing (Issue #2929).
#
#   config-snapshot.sh snap <outdir> [host...]   build + record the current tree (default: p620 razer p510)
#   config-snapshot.sh diff <base-dir> <new-dir> compare two snapshots; exit 1 on any difference
#
# The toplevel is evaluated with system.configurationRevision pinned to a constant, so two commits that
# configure the same system give the same .drv. Equal .drv = identical system, file contents included.
# Builds run locally (p510's config too); nothing is copied to or activated on any host.
set -euo pipefail
hosts_default=(p620 razer p510)
user=olafkfreund

eval_host() { # <flake-dir> <host> <nix-expr over c (config) and hm (home-manager user config)>
  nix eval --impure --json --expr "let f = builtins.getFlake \"git+file://$1\";
    c = (f.nixosConfigurations.$2.extendModules { modules = [ ({ lib, ... }: {
      system.configurationRevision = lib.mkForce \"snapshot\"; }) ]; }).config;
    hm = c.home-manager.users.$user; in $3"
}

case "${1:-}" in
  snap)
    out=$2
    shift 2
    mkdir -p "$out"
    dir=$(git rev-parse --show-toplevel)
    for h in "${@:-${hosts_default[@]}}"; do
      eval_host "$dir" "$h" 'c.system.build.toplevel.drvPath' | jq -r . >"$out/$h.drv"
      eval_host "$dir" "$h" '{
      syspkgs = map (p: p.name or "?") c.environment.systemPackages;
      hmpkgs = map (p: p.name or "?") hm.home.packages;
      units = builtins.attrNames c.systemd.units;
      userunits = builtins.attrNames hm.systemd.user.services;
      etc = builtins.attrNames c.environment.etc;
      hmfiles = builtins.attrNames hm.home.file; }' >"$out/$h.json"
      nix build --no-link --print-out-paths "$(cat "$out/$h.drv")^out" >"$out/$h.out"
      echo "$h built $(cat "$out/$h.out")"
    done
    ;;
  diff)
    b=$2
    n=$3
    rc=0
    for f in "$b"/*.drv; do
      h=$(basename "$f" .drv)
      if cmp -s "$f" "$n/$h.drv"; then
        echo "$h: IDENTICAL"
        continue
      fi
      rc=1
      echo "$h: CHANGED"
      for k in syspkgs hmpkgs units userunits etc hmfiles; do
        d=$(diff <(jq -r ".$k[]" "$b/$h.json" | sort) <(jq -r ".$k[]" "$n/$h.json" | sort) | grep '^[<>]' || true)
        if [ -n "$d" ]; then
          echo "  $k:"
          echo "$d" | sed 's/^/    /'
        fi
      done
      echo "  closure:"
      nix store diff-closures "$(cat "$b/$h.out")" "$(cat "$n/$h.out")" | sed 's/^/    /' | head -40
    done
    exit $rc
    ;;
  *)
    sed -n 2,9p "$0"
    exit 2
    ;;
esac
