#!/usr/bin/env just --justfile

# Default recipe to display available commands
default:
    @just --list

# Refuse to activate anything built from a branch other than main (#2052).
# /etc/nixos is this checkout, so deploying a branch ships it to the host.
[group('private')]
_require-main:
    #!/usr/bin/env bash
    set -euo pipefail
    branch=$(git branch --show-current)
    rev=$(git rev-parse --short HEAD)
    # A worktree detached exactly at origin/main is main; any other detached HEAD is not.
    if [ -z "$branch" ] && [ "$(git rev-parse HEAD)" = "$(git rev-parse -q --verify origin/main || true)" ]; then
      branch=main
    fi
    if [ "$branch" != "main" ] && [ "${ALLOW_BRANCH_DEPLOY:-}" != "1" ]; then
      echo "!! refusing to deploy from '${branch:-detached HEAD}' ($rev), not main" >&2
      echo "   /etc/nixos is this checkout; deploying a branch ships it to the host." >&2
      echo "   switch back:     git switch main && git pull --ff-only" >&2
      echo "   deploy it anyway: ALLOW_BRANCH_DEPLOY=1 just <recipe>" >&2
      exit 1
    fi
    echo ">> deploying ${branch:-detached HEAD} @ $rev"

# Deploy to local system using nh
[group('deploy')]
deploy: _require-main
    nh os switch

# Guarded by name (#2951): bus hook (announce), coder guard (blocked). Rename it in the guards too.

# Update local system using nh
[group('update')]
update: _require-main
    nh os switch --update

# Idiot-proof update + commit + deploy (local OR remote). Does:
#   1. nix flake update (scope = 'all' by default; pass 'nixpkgs' or any input name to scope down)
#   2. no-op exit if nothing moved
#   3. test-build target host closure (aborts if fails)
#   4. commit flake.lock to main + git push (lock never gets orphaned)
#   5. nh os switch (local) OR nh os switch --target-host HOST (remote via SSH)
#
# HOST defaults to the local hostname; any SSH-reachable host in ~/.ssh/config
# works too. SCOPE defaults to 'all' (every input). Pass 'nixpkgs' to scope it
# down to just the nixpkgs pin, or pass a specific input name (e.g.
# 'home-manager', 'claude-desktop-linux') to bump one input.
#
# Examples:
#   just update-commit-deploy                     # local, all inputs
#   just update-commit-deploy p620                # explicit local host, all inputs
#   just update-commit-deploy razer               # remote via SSH, all inputs
#   just update-commit-deploy p510 nixpkgs        # remote, nixpkgs only
#   just update-commit-deploy razer home-manager  # remote, single input
[group('update')]
update-commit-deploy HOST="$(hostname)" SCOPE="all":
    ./scripts/update-commit-deploy.sh {{HOST}} {{SCOPE}}

# Guarded by name (#2951): coder guard (blocked: it commits and pushes). Rename it in the guards too.

# Deploy guards drop this as non-disruptive (claude-guard-prepare.sh, #3083).
# Stage 1 of split deploy: bump lock + build + commit + PR-merge, no switch.
# Use when you want to update + build + commit but defer the actual switch
# (e.g. target host is offline, or you want to switch on your own schedule
# with `nhs HOST` later). SCOPE defaults to 'all'; pass 'nixpkgs' or an input
# name to scope it down.
[group('update')]
update-commit HOST="$(hostname)" SCOPE="all":
    ./scripts/update-commit-deploy.sh {{HOST}} {{SCOPE}} --no-deploy

# Deploy guards drop this as non-disruptive (claude-guard-prepare.sh, #3083).
# Preview updates with detailed package changes (before building)
[group('update')]
preview-updates HOST="$(hostname)":
    @echo "🔍 Previewing updates for {{HOST}}..."
    ./scripts/preview-updates.sh {{HOST}}

# Deploy guards drop this as non-disruptive (claude-guard-prepare.sh, #3083).
# Show what the LAST update changed: Added / Removed / Upgraded packages
# between the two most recent system generations (nvd-backed; local or remote).
# Complements nh's built-in diff, which is version-level only and skips remote
# --target-host deploys.
#   just system-diff            # this host, last two generations
#   just system-diff razer      # remote host over SSH
[group('update')]
system-diff HOST="-":
    ./scripts/system-diff.sh {{HOST}}

# Run comprehensive validation suite
[group('test')]
validate:
    @echo "🧪 Running comprehensive validation..."
    @echo "📝 Full flake check (includes all hosts, modules, and derivations)..."
    @echo "⚠️  Note: This takes ~4 minutes but catches module system errors"
    nix flake check
    @echo "✅ All validations complete!"

# Quick validation (faster, less comprehensive)
[group('test')]
validate-quick:
    @echo "⚡ Running quick validation..."
    ./scripts/validate-config.sh --quick

# Run all pre-commit hooks
[group('lint')]
pre-commit-run:
    @echo "🧪 Running all pre-commit hooks..."
    pre-commit run --all-files

# Lint all files (whole-tree nixpkgs-lint-community + per-file deadnix)
[group('lint')]
lint-all:
    @echo "🔍 Linting all files..."
    nixpkgs-lint . || true
    pre-commit run deadnix --all-files || true
    pre-commit run shellcheck --all-files || true
    pre-commit run markdownlint --all-files || true
    @echo "✅ All files linted!"

# Test all configurations in parallel (FASTER)
[group('test')]
test-all-parallel:
    @echo "🧪 Testing all NixOS configurations in parallel..."
    @( nix build .#nixosConfigurations.p620.config.system.build.toplevel --no-link --show-trace && echo "✅ P620" || { echo "❌ P620"; exit 1; } ) & p620_pid=$!; \
    ( nix build .#nixosConfigurations.razer.config.system.build.toplevel --no-link --show-trace && echo "✅ Razer" || { echo "❌ Razer"; exit 1; } ) & razer_pid=$!; \
    ( nix build .#nixosConfigurations.p510.config.system.build.toplevel --no-link --show-trace && echo "✅ P510" || { echo "❌ P510"; exit 1; } ) & p510_pid=$!; \
    failed=0; wait "$p620_pid" || failed=1; wait "$razer_pid" || failed=1; wait "$p510_pid" || failed=1; \
    [ "$failed" -eq 0 ] || exit 1; echo "✅ All parallel tests completed!"

# Deploy guards drop this as non-disruptive (claude-guard-prepare.sh, #3083).
# Test specific host configuration
[group('test')]
test-host HOST:
    @echo "🧪 Testing {{HOST}} configuration..."
    nix build .#nixosConfigurations.{{HOST}}.config.system.build.toplevel --show-trace

# Deploy guards drop this as non-disruptive (claude-guard-prepare.sh, #3083).
# Check a host's EFI System Partition has room for another generation.
# The bootloader writes the new kernel+initrd BEFORE pruning the old ones, so
# "not full" is not the same as "can deploy". Read-only by default.
[group('maintenance')]
boot-space HOST="$(hostname)":
    ./scripts/check-boot-space.sh {{HOST}}

# Guarded by name (#2951): bus hook (announce), coder guard (blocked), p510 guard when HOST is p510. Rename it in the guards too.

# Same check, but reclaim space when it is short (prunes old generations and
# lets the bootloader installer garbage-collect the ESP entries).
[group('maintenance')]
boot-space-clean HOST="$(hostname)":
    ./scripts/check-boot-space.sh {{HOST}} --clean

# ESP headroom across every host, at a glance.
[group('maintenance')]
boot-space-all:
    @for h in p620 razer p510; do ./scripts/check-boot-space.sh "$h" || true; done

# The p510 activation guard: blocks, opens on an explicit approval, leaves reads
# alone. Fast and offline -- it extracts the shell out of the module and runs it.
#
# Named "guards" and not "...-deploy-guard" on purpose: the announce guard
# matches `just [a-z-]*deploy`, so a read-only target with "deploy" in its name
# is refused as though it were a deployment. Over-blocking on that pattern is
# the right default; the cheap fix is the name.
[group('test')]
test-guards:
    @python3 ./scripts/test-p510-deploy-guard.py
    @python3 ./scripts/test-bus-guard.py
    @bash ./scripts/test-nixos-issue-audit.sh
    @bash ./scripts/test-sync-remote-checkout.sh
    @bash ./scripts/test-nhs-checkout-sync.sh
    @bash ./modules/programs/claude-coder-guard.test.sh
    @bash ./modules/programs/claude-guard-prepare.test.sh
    @bash ./scripts/test-guard-safe-recipes.sh

# Check for available updates
[group('update')]
check-updates:
    @echo "📦 Checking for available updates..."
    ./scripts/check-nixos-updates.sh

# Deploy guards drop this as non-disruptive (claude-guard-prepare.sh, #3083).
# Dry-run rebuild to see what would change
[group('test')]
dry-run HOST="p620":
    @echo "🔍 Dry-run for {{HOST}}..."
    nixos-rebuild dry-activate --flake .#{{HOST}} --show-trace

# Test secrets decryption
[group('secrets')]
test-secrets:
    @echo "🔐 Testing secrets decryption..."
    @if [ -f "secrets/user-password-olafkfreund.age" ]; then \
        agenix -d secrets/user-password-olafkfreund.age > /dev/null && echo "✅ Secrets decrypt successfully" || echo "❌ Secret decryption failed"; \
    else \
        echo "⚠️  No secrets found to test"; \
    fi

# Compare registered MCP servers against what this configuration builds (#1933)
[group('test')]
check-mcp:
    #!/usr/bin/env bash
    # Reports; never rewrites. ~/.claude.json belongs to Claude Code.
    target="$HOME/.claude.json"
    if [ ! -e "$target" ]; then
        echo "no $target — nothing registered yet"
        exit 0
    fi
    host=$(hostname)
    # Build the home activation package first. `nix eval` alone yields a store
    # path whose deriver is not instantiated locally, so realising it fails
    # with "no substituter can build it" unless something already built that
    # exact content. Building here makes the check self-contained (~40s warm).
    echo "building the declared MCP set…"
    if ! nix build --no-link \
         ".#nixosConfigurations.$host.config.home-manager.users.$USER.home.activationPackage" 2>/dev/null; then
        echo "⚠️  could not build the home activation package for $host"
        exit 0
    fi
    # Derive the declared set from the configuration, not a hand-written list,
    # so a newly declared server is covered without touching this recipe.
    desired=$(nix eval --raw \
        ".#nixosConfigurations.$host.config.home-manager.users.$USER.home.activation.claudeSharedMcpServers.data" \
        2>/dev/null | grep -o '/nix/store/[a-z0-9]*-claude-shared-mcp.json' | head -1)
    # Without a readable $desired every comparison below silently reads
    # nothing and every server looks unmanaged — a green-looking lie.
    if [ -z "$desired" ] || [ ! -e "$desired" ]; then
        echo "⚠️  could not resolve the declared MCP set for $host"
        exit 0
    fi
    drifted=0; missing=0
    echo "🔍 MCP registrations on $host"
    for name in $(jq -r '.mcpServers | keys[]' "$target"); do
        reg=$(jq -r --arg n "$name" '.mcpServers[$n].command // ""' "$target")
        want=$(jq -r --arg n "$name" '.mcpServers[$n].command // ""' "$desired")
        if [ -n "$want" ]; then
            if [ "$reg" != "$want" ]; then
                echo "  ❌ drifted   $name"
                echo "       registered: $reg"
                echo "       configured: $want"
                drifted=$((drifted + 1))
            else
                echo "  ✅ current   $name"
            fi
        elif [ "${reg#/}" != "$reg" ] && [ ! -e "$reg" ]; then
            # Only an absolute path can be "missing". A bare command like sh,
            # bash or uvx is resolved via PATH at spawn time and says nothing
            # about garbage collection.
            echo "  💥 missing   $name — registered path does not exist"
            echo "       $reg"
            missing=$((missing + 1))
        elif [ -n "$reg" ]; then
            echo "  ·  unmanaged $name (registered by hand, not declared here)"
        fi
    done
    vestigial="$HOME/.local/state/nix/gcroots/ollama-mcp"
    if [ -L "$vestigial" ]; then
        echo "  ·  vestigial gcroot $vestigial -> $(readlink "$vestigial")"
        echo "       nothing reads it since #1933; safe to delete"
    fi
    echo
    echo "A change here takes effect on the NEXT SESSION, not on the rebuild:"
    echo "Claude Code holds each server's process and tool schemas for the"
    echo "life of a session. Rebuild, restart the session, then re-check."
    [ "$missing" -eq 0 ] || { echo "❌ $missing registered path(s) missing"; exit 1; }
    [ "$drifted" -eq 0 ] && echo "✅ no drift" || echo "⚠️  $drifted drifted; switch to reconcile"

# Check Nix file syntax across the entire configuration
[group('test')]
check-syntax:
    #!/usr/bin/env bash
    echo "🔍 Checking Nix file syntax..."
    error_found=false
    while IFS= read -r -d '' file; do
        if ! nix-instantiate --parse "$file" > /dev/null 2>&1; then
            echo "❌ Syntax error in $file"
            error_found=true
        fi
    done < <(find . -name "*.nix" -not -path "./result*" -not -path "./.git/*" -print0)
    if [ "$error_found" = false ]; then
        echo "✅ All Nix files have valid syntax"
    fi

# Refuse while the host's guarded upgrade is mid-switch (nixarchy#1946). The
# guarded side refuses while a manual deploy runs, so neither can switch over the
# other.
_no-guarded-upgrade HOST:
    #!/usr/bin/env bash
    set -euo pipefail
    probe='systemctl is-active --quiet nixos-upgrade.service && exit 3; test -e /var/lib/guarded-upgrade/transaction && exit 4; exit 0'
    if [ "$(hostname)" = "{{HOST}}" ]; then rc=0; bash -c "$probe" || rc=$?; else rc=0; ssh -o BatchMode=yes {{HOST}} "$probe" || rc=$?; fi
    case $rc in
      0) ;;
      3) echo "{{HOST}}: the guarded upgrade is running; wait for nixos-upgrade.service to finish" >&2; exit 1 ;;
      4) echo "{{HOST}}: a guarded upgrade transaction is open; it reconciles on its next run" >&2; exit 1 ;;
      *) echo "{{HOST}}: could not ask whether a guarded upgrade is running (rc=$rc)" >&2; exit 1 ;;
    esac

# Deploy to razer laptop (Intel/NVIDIA) - OPTIMIZED
[group('deploy')]
razer: _require-main (_no-guarded-upgrade "razer") (_sign-drv "razer")
    ./scripts/sync-remote-checkout.sh around razer -- nixos-rebuild switch --flake .#razer --target-host razer --build-host razer --sudo --no-reexec --keep-going

# Deploy to p620 workstation (AMD) - OPTIMIZED
[group('deploy')]
p620: _require-main (_no-guarded-upgrade "p620")
    sudo nixos-rebuild switch --flake .#p620

# Deploy to p510 workstation (Intel Xeon/NVIDIA) - OPTIMIZED
[group('deploy')]
p510: _require-main
    just p510-clear-sessions
    ./scripts/sync-remote-checkout.sh around p510 -- nixos-rebuild switch --flake .#p510 --target-host p510 --build-host p510 --sudo --no-reexec --keep-going

# Guarded by name (#2951): bus hook (announce), coder guard (blocked), p510 guard. Rename it in the guards too.

# p510 runs GNOME for gnome-remote-desktop, so a leftover session keeps a
# systemd --user manager alive with ~47 GUI units that can't start without a
# display. switch-to-configuration then tries to start them, reloads the user
# dbus-broker mid-flight, loses its own bus connection and returns exit 4.
# Clearing idle sessions first removes most of that noise. It does NOT
# guarantee exit 0 — verify the end state, not the exit code:
#   readlink -f /run/current-system && systemctl --failed
# Drop stale olafkfreund sessions on p510 before a switch
[group('deploy')]
p510-clear-sessions:
    #!/usr/bin/env bash
    set -uo pipefail
    echo "🧹 Clearing stale olafkfreund sessions on p510..."
    ssh p510 'bash -s' <<'REMOTE'
    set -uo pipefail
    # Columns: SESSION UID USER SEAT LEADER CLASS TTY IDLE ...
    # Only idle, TTY-less user sessions are stale. Never touch a session with a
    # TTY (a live login / tmux) and never our own ssh session.
    self="${XDG_SESSION_ID:-none}"
    killed=0
    while read -r id uid _user _seat _leader class tty _rest; do
      [ "$uid" = "1000" ] || continue
      [ "$class" = "user" ] || continue
      [ "$tty" = "-" ] || continue
      [ "$id" = "$self" ] && continue
      loginctl terminate-session "$id" 2>/dev/null
      # A session whose leader already died sits in State=closing forever and
      # terminate-session is a no-op on it — its scope keeps running abandoned
      # (seen: a wedged `docker run … | head` from an old debug session held one
      # open for 3 days). Stop the scope directly in that case.
      if loginctl show-session "$id" -p Id >/dev/null 2>&1; then
        sudo systemctl stop "session-$id.scope" 2>/dev/null || true
      fi
      loginctl show-session "$id" -p Id >/dev/null 2>&1 || killed=$((killed+1))
    done < <(loginctl list-sessions --no-legend)
    systemctl --user reset-failed 2>/dev/null || true
    echo "  terminated $killed stale session(s); user manager: $(systemctl --user is-system-running 2>&1)"
    REMOTE

# Deploy guards drop this as non-disruptive (claude-guard-prepare.sh, #3083).
# Show configuration diff between current and new build
[group('test')]
diff HOST:
    @echo "📊 Showing configuration diff for {{HOST}}..."
    @current=$(readlink -f /run/current-system 2>/dev/null || echo "no-current") && new=$(nix build .#nixosConfigurations.{{HOST}}.config.system.build.toplevel --no-link --print-out-paths) && if [ "$current" != "no-current" ]; then nix store diff-closures $current $new; else echo "No current system configuration found"; fi

# Guarded by name (#2951): bus hook (announce), coder guard (blocked). Rename it in the guards too.

# Clean up old generations and garbage collect
[group('maintenance')]
cleanup GENERATIONS="7":
    @echo "🧹 Cleaning up old generations (keeping {{GENERATIONS}})..."
    sudo nix-collect-garbage --delete-older-than {{GENERATIONS}}d
    @echo "🧹 Optimizing nix store..."
    nix store optimise

# Show system health and status
[group('maintenance')]
status:
    @echo "🏥 System Health Status"
    @echo "======================="
    @echo "💾 Disk Usage:"
    df -h / | tail -1
    @echo "🧠 Memory Usage:"
    free -h | grep Mem
    @echo "📦 Nix Store Size:"
    du -sh /nix/store 2>/dev/null || echo "Cannot access /nix/store"
    @echo "🗂️  Generations Count:"
    sudo nix-env --list-generations --profile /nix/var/nix/profiles/system | wc -l
    @echo "⚡ Last Update:"
    stat -c %y /run/current-system 2>/dev/null || echo "Unknown"

# Guarded by name (#2951): bus hook (announce), coder guard (blocked). Rename it in the guards too.

# Garbage collect old generations
[group('maintenance')]
gc:
    @echo "🗑️ Collecting garbage (keeping current generation)..."
    sudo nix-collect-garbage --delete-old
    @echo "✅ Garbage collection complete!"

# Format all Nix files using nixpkgs-fmt (preferred over alejandra)
[group('lint')]
format:
    find . -name "*.nix" -not -path "./result*" -not -path "./.git/*" -exec nixpkgs-fmt {} +

# Quick commands for common operations
[group('test')]
quick-test:
    just test-all-parallel

# Smart deploy only if configuration changed
[group('deploy')]
quick-deploy HOST: _require-main
    @echo "🧠 Smart deployment to {{ HOST }}..."
    @new=$(nix build .#nixosConfigurations.{{ HOST }}.config.system.build.toplevel --no-link --print-out-paths) \
        || { echo "❌ Build failed for {{ HOST }}, not deploying"; exit 1; }; \
    if [ "$(ssh {{ HOST }} readlink /run/current-system 2>/dev/null)" = "$new" ]; then \
        echo "🔄 No changes detected for {{ HOST }}, skipping deployment"; \
        ./scripts/sync-remote-checkout.sh around {{ HOST }} -- true; \
    else \
        echo "📝 Changes detected, deploying to {{ HOST }}..."; \
        just {{ HOST }}; \
    fi

# Manage secrets interactively
[group('secrets')]
secrets:
    ./scripts/manage-secrets.sh

# Check secrets status
[group('secrets')]
secrets-status:
    ./scripts/manage-secrets.sh status

# Deploy guards drop this as non-disruptive (claude-guard-prepare.sh, #3083).
# Check secrets status on specific host
[group('secrets')]
secrets-status-host HOST:
    @echo "🔑 Checking secrets status on {{HOST}}..."
    ssh {{HOST}} "sudo ls -la /run/agenix/ || echo 'Agenix directory not found'"
    ssh {{HOST}} "sudo systemctl status agenix --no-pager || echo 'Agenix service not running'"

# Guarded by name (#2951): bus hook (announce), coder guard (blocked), p510 guard when HOST is p510. Rename it in the guards too.

# Fix agenix issues on remote host
[group('secrets')]
fix-agenix-remote HOST:
    @echo "🔧 Attempting to fix agenix issues on {{HOST}}..."
    ssh {{HOST}} "sudo systemctl stop agenix || true"
    ssh {{HOST}} "sudo rm -rf /run/agenix.d || true"
    ssh {{HOST}} "sudo systemctl start agenix || echo 'Agenix service failed to start'"
    ssh {{HOST}} "sudo systemctl status agenix --no-pager"

# Build locally, deploy remotely (for slow remote hosts)
[group('deploy')]
deploy-local-build HOST: _require-main
    @echo "🏗️ Building {{HOST}} locally, deploying remotely..."
    ./scripts/sync-remote-checkout.sh around {{HOST}} -- nixos-rebuild switch --flake .#{{HOST}} --target-host {{HOST}} --sudo --no-reexec --keep-going

# Guarded by name (#2951): coder guard (blocked: signs with the host key). Rename it in the guards too.

# Deploy guards drop this as non-disruptive (claude-guard-prepare.sh, #3083).
# Sign the .drv closure so an untrusted --build-host accepts the upload (#2758).
[group('private')]
_sign-drv HOST:
    #!/usr/bin/env bash
    set -euo pipefail
    # shortcut: skips when the invoking host has no key (p510); the copy then needs a trusted receiver
    [ -e /run/agenix/nix-signing-key ] || { echo "no signing key here, skipping"; exit 0; }
    drv=$(nix eval --raw ".#nixosConfigurations.{{HOST}}.config.system.build.toplevel.drvPath")
    sudo nix store sign -r --key-file /run/agenix/nix-signing-key "$drv"

# Build on P620, deploy to target host
[group('deploy')]
deploy-via-p620 HOST: _require-main (_no-guarded-upgrade HOST) (_sign-drv HOST)
    @echo "🏗️ Building {{HOST}} on P620 cache server, deploying to {{HOST}}..."
    @echo "📡 Step 1: Building on P620..."
    @# Already on p620? Build locally — SSHing to ourselves just to build is a
    @# pointless round-trip (and used to fail outright when p620.lan died).
    if [ "$(hostname)" = "p620" ]; then \
        nixos-rebuild build --flake .#{{HOST}}; \
    else \
        nixos-rebuild build --flake .#{{HOST}} --build-host p620; \
    fi
    @echo "📦 Step 2: Deploying to {{HOST}}..."
    @# Deploying to ourselves? Activate locally. --target-host SSHes to our own
    @# name, so a host entry in ~/.ssh/config that no longer resolves fails the
    @# copy step after a build that already succeeded. Same reasoning as Step 1.
    if [ "$(hostname)" = "{{HOST}}" ]; then \
        sudo nixos-rebuild switch --flake .#{{HOST}} --no-reexec; \
    else \
        ./scripts/sync-remote-checkout.sh around {{HOST}} -- nixos-rebuild switch --flake .#{{HOST}} --target-host {{HOST}} --sudo --no-reexec --keep-going; \
    fi
    @echo "✅ Deployment complete! {{HOST}} is using P620's cache."

# Guarded by name (#2951): coder guard (blocked: signs with the host key). Rename it in the guards too.

# Deploy guards drop this as non-disruptive (claude-guard-prepare.sh, #3083).
# Build on P620 for target host (build only, no deployment)
[group('deploy')]
build-on-p620 HOST: (_sign-drv HOST)
    @echo "🏗️ Building {{HOST}} on P620 (build only)..."
    nixos-rebuild build --flake .#{{HOST}} --build-host p620
    @echo "✅ Build complete! Deploy with: just deploy-via-p620 {{HOST}}"

# Test all hosts can be reached
[group('maintenance')]
ping-hosts:
    @echo "🏓 Pinging all hosts..."
    @# ssh, not ping: the hostnames only resolve through ~/.ssh/config (Tailscale
    @# MagicDNS / LAN IP) since the router swap took the .lan domain away, and a
    @# bare `ping p620` would answer from /etc/hosts on p620 itself.
    @# `$host`, not `$$host`: `$$` is a Makefile escape, and just passes recipe
    @# text to the shell verbatim — `$$` reaches sh as the PID.
    @for host in p620 razer p510; do \
        echo -n "$host: "; \
        ssh -o ConnectTimeout=5 -o BatchMode=yes $host true >/dev/null 2>&1 && echo "✅ reachable" || echo "❌ unreachable"; \
    done

# === Documentation site (MkDocs Material) ===

# Build the documentation site reproducibly with Nix (-> ./result)
[group('docs')]
docs-build:
    @echo "📚 Building documentation site with Nix..."
    nix build .#docs --print-build-logs
    @echo "✅ Site built. Open: file://$(readlink -f result)/index.html"

# Serve the docs locally with live reload (requires: nix develop .#docs)
[group('docs')]
docs-serve:
    @echo "📚 Serving docs at http://127.0.0.1:8000 (Ctrl+C to stop)..."
    nix develop .#docs --command mkdocs serve

# Strict build to catch broken links / nav issues (used as a quality gate)
[group('docs')]
docs-check:
    @echo "🔍 Strict documentation build (fails on warnings)..."
    nix develop .#docs --command mkdocs build --strict --site-dir /tmp/nixos-docs-check
    @echo "✅ Strict build passed."
