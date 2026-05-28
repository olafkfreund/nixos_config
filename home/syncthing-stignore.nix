# Syncthing .stignore — declarative allowlists for ~/.claude and ~/.gemini
#
# Both folders are synced cluster-wide via Syncthing (folders claude-config
# and gemini-config). We restrict what actually syncs to a small curated
# allowlist: skills/commands/agents/plugins/CLAUDE.md for claude;
# config/skills/commands/agents/hooks/extensions/GEMINI.md/settings.json
# for gemini. Everything else (session transcripts, file-history, caches,
# antigravity runtime, ...) is excluded by a trailing `*` catch-all.
#
# force = true: Syncthing wrote these files imperatively before we
# Nixified them, so the first activation must clobber the on-disk copies.
# After that they're symlinks to the Nix store and Syncthing reloads them
# automatically on change (verified — see folder.fsWatcher).
#
# To change patterns, edit this file and re-deploy. Do NOT edit ~/.claude/
# .stignore or ~/.gemini/.stignore directly — your edits would be reverted
# on the next nixos-rebuild switch.
{ ... }:
{
  home.file.".claude/.stignore" = {
    force = true;
    text = ''
      // ~/.claude/.stignore — allowlist mode (managed by home/syncthing-stignore.nix)
      // Only paths matched by "!" rules below are synced.
      // Everything else is ignored by the final catch-all.

      // ─── Sensitive: never sync, even by accident ───
      .credentials.json

      // ─── Sync-conflict litter: drop everywhere ───
      *sync-conflict*

      // ─── ALLOWLIST: only these sync ───
      !CLAUDE.md
      !skills/**
      !commands/**
      !agents/**
      !plugins/**

      // ─── Catch-all: ignore everything else ───
      *
    '';
  };

  home.file.".gemini/.stignore" = {
    force = true;
    text = ''
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
  };
}
