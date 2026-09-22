# Syncthing .stignore — declarative allowlists for ~/.claude and ~/.gemini
#
# Both folders are synced cluster-wide via Syncthing (folders claude-config
# and gemini-config). We restrict what actually syncs to a small curated
# allowlist: skills/commands/agents/plugins/CLAUDE.md for claude;
# config/skills/commands/agents/hooks/extensions/GEMINI.md/settings.json
# for gemini. Everything else (session transcripts, file-history, caches,
# antigravity runtime, ...) is excluded by a trailing `*` catch-all.
#
# Written as real files by an activation step, NOT as home.file symlinks.
# Syncthing only reloads ignores when the file's mtime changes, and every
# /nix/store file has mtime 1, so a symlinked .stignore was never reloaded:
# on 2026-09-22 every host was running rules from its last Syncthing start
# (p510 still lacked /skills/gog). The step rewrites a file only when its
# content changes, so the mtime moves exactly when Syncthing must reload.
# Check what Syncthing actually loaded with
#   curl -H "X-API-Key: $KEY" 127.0.0.1:8384/rest/db/ignores?folder=claude-config
#
# To change patterns, edit this file and re-deploy. Do NOT edit ~/.claude/
# .stignore or ~/.gemini/.stignore directly — your edits would be reverted
# on the next nixos-rebuild switch.
{ config, lib, pkgs, ... }:
let
  # Skill directories home-manager owns under a synced folder, derived from
  # home.file rather than listed by hand, so a newly added skill is covered
  # without anyone remembering this file exists.
  #
  # Why they must not sync: home-manager populates them with /nix/store
  # symlinks, and Syncthing replicates a symlink verbatim. Whichever host
  # activated last shipped ITS store path to the other, where that path does
  # not exist -- on 2026-09-13 nine skills on razer (gog, notebooklm,
  # agent-bus, dns, obsidian, 1password, nixi, ...) pointed into p620's
  # home-manager-files and were dangling. It ping-pongs: re-activating razer
  # fixes razer and breaks p620 seconds later. ~/.codex/skills is not synced
  # and none of its links ever dangled, which is what pinned it on Syncthing.
  #
  # Only these are carved out. `!skills/**` below still syncs skills installed
  # imperatively, which are real files and replicate correctly.
  #
  # `subdir` is the synced path under the folder: `skills` for both, plus
  # `config/skills` for .gemini, where Antigravity reads skills and the
  # allowlist syncs `!config/**` (#1958).
  managedSkillIgnores = folder: subdir:
    lib.concatMapStrings (name: "/${subdir}/${name}\n") (lib.unique (map
      (path: lib.elemAt (lib.splitString "/" path)
        (lib.length (lib.splitString "/" "${folder}/${subdir}")))
      (lib.filter (lib.hasPrefix "${folder}/${subdir}/") (lib.attrNames config.home.file))));

  # Hand-made skill links whose target exists on only some hosts: omgato's
  # plugin is on p620 only, herdr's skill on p620 + razer, and test-skill's
  # source tree on razer only. Synced, each dangled on the other hosts, and
  # deleting a dangling copy would sync the deletion to the host where it
  # works. Ignored, every host keeps its own copy (or none).
  hostLocalSkillIgnores = subdir:
    lib.concatMapStrings (name: "/${subdir}/${name}\n")
      [ "herdr" "omarchy-omgato" "test-skill" ];

  # nixarchy relinks every skill in its omarchy tree into ~/.claude/skills on
  # each activation (modules/home.nix, "agent skills relinked on every
  # activation"). The tree differs per host (p510 has preinstalls = false),
  # so these links dangled wherever another host's tree path landed. The
  # names only exist in the built tree -- reading it at eval time would be
  # import-from-derivation -- so they are listed. Taken from
  # ~/.agents/skills on 2026-09-22; a new nixarchy skill needs adding here.
  # Exact names, not `/skills/nixos-*`: that would also stop the real,
  # synced nixos-standards skill.
  nixarchySkillIgnores = lib.concatMapStrings (name: "/skills/${name}\n") [
    "devenv"
    "diagnose-crash"
    "nixarchy"
    "nixos"
    "nixos-ai"
    "nixos-android"
    "nixos-binaries"
    "nixos-config-repo"
    "nixos-doctor"
    "nixos-fleet"
    "nixos-gaming"
    "nixos-gpu"
    "nixos-performance"
    "nixos-secrets"
    "nixos-security"
    "nixos-services"
  ];

  claudeIgnores = pkgs.writeText "claude-stignore" ''
    // ~/.claude/.stignore — allowlist mode (managed by home/syncthing-stignore.nix)
    // Only paths matched by "!" rules below are synced.
    // Everything else is ignored by the final catch-all.

    // ─── Sensitive: never sync, even by accident ───
    .credentials.json

    // ─── Sync-conflict litter: drop everywhere ───
    *sync-conflict*

    // ─── Per-host skill links: store or local symlinks, never sync ───
    // (first match wins, so these beat !skills/**)
    ${managedSkillIgnores ".claude" "skills"}${hostLocalSkillIgnores "skills"}${nixarchySkillIgnores}
    // ─── ALLOWLIST: only these sync ───
    !CLAUDE.md
    !skills/**
    !commands/**
    !agents/**
    !plugins/**

    // ─── Catch-all: ignore everything else ───
    *
  '';

  geminiIgnores = pkgs.writeText "gemini-stignore" ''
    // ~/.gemini/.stignore — allowlist mode (managed by home/syncthing-stignore.nix)
    // Only paths matched by "!" rules below are synced.
    // Everything else is ignored by the final catch-all.

    // ─── Sensitive: never sync, even by accident ───
    oauth_creds.json
    google_accounts.json

    // ─── Per-machine state: never useful cross-host ───
    installation_id
    user_id
    state.json
    projects.json
    trustedFolders.json
    settings.json.orig
    settings.nix

    // ─── Sync-conflict litter: drop everywhere ───
    *sync-conflict*

    // ─── Per-host skill links: store or local symlinks, never sync ───
    // (first match wins, so these beat !skills/**)
    ${managedSkillIgnores ".gemini" "skills"}${managedSkillIgnores ".gemini" "config/skills"}${hostLocalSkillIgnores "config/skills"}
    // ─── ALLOWLIST: only these sync ───
    !GEMINI.md
    !settings.json
    !config/**
    !skills/**
    !commands/**
    !agents/**
    !hooks/**
    !extensions/**

    // ─── Catch-all: ignore everything else ───
    *
  '';

  home = config.home.homeDirectory;
in
{
  # After linkGeneration, which removes the .stignore symlinks earlier
  # generations installed. A leftover symlink is replaced, not written
  # through; unchanged content leaves the file (and its mtime) alone.
  home.activation.syncthingIgnores = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    for pair in "${claudeIgnores}:${home}/.claude/.stignore" \
                "${geminiIgnores}:${home}/.gemini/.stignore"; do
      src="''${pair%%:*}"
      dst="''${pair#*:}"
      run mkdir -p "$(dirname "$dst")"
      [ -L "$dst" ] && run rm -f "$dst"
      if ! cmp -s "$src" "$dst"; then
        run install -m 644 "$src" "$dst.tmp" && run mv -f "$dst.tmp" "$dst"
      fi
    done
  '';
}
