# Google Antigravity — declarative config bridge
#
# Antigravity (the `agy` CLI + IDE) keeps most of its config under ~/.gemini/.
# This module makes the *user-authored, reproducible* pieces declarative while
# leaving agent-managed runtime state alone:
#
#   - ~/.gemini/AGENTS.md      → declaratively owned global cross-tool rules
#                                (Antigravity reads it; Claude Code reads the
#                                per-repo AGENTS.md). NEW file — nothing to lose.
#   - ~/.gemini/config/mcp_config.json → ADDITIVELY synced: a small set of
#                                clean, secret-free stdio MCP servers is merged
#                                in, but every server the user already has
#                                ALWAYS wins. Never removes or overwrites.
#
# Deliberately NOT managed (agent/runtime state — would break Antigravity):
#   - ~/.gemini/GEMINI.md       (agent auto-memory — Antigravity writes it)
#   - ~/.gemini/oauth_creds.json, state.json, brain/, history, etc.
#
# Note: Antigravity is OAuth-only (no BYOK), so API keys are NOT declarable.
{ config
, lib
, pkgs
, ...
}:
let
  cfg = config.programs.antigravityConfig;

  geminiDir = "${config.home.homeDirectory}/.gemini";

  # Clean, secret-free stdio MCP servers to share into Antigravity. These map
  # 1:1 onto Antigravity's command/args/env schema. SSE/secret-bound servers
  # from the Claude set are intentionally excluded (different transport / would
  # leak credentials into a plaintext file).
  sharedMcpServers = {
    context7 = {
      command = "${pkgs.nodejs}/bin/npx";
      args = [ "-y" "@upstash/context7-mcp@latest" ];
    };
    sequential-thinking = {
      command = "${pkgs.nodejs}/bin/npx";
      args = [ "-y" "@modelcontextprotocol/server-sequential-thinking" ];
    };
  };

  sharedMcpFile = (pkgs.formats.json { }).generate "antigravity-shared-mcp.json" {
    mcpServers = sharedMcpServers;
  };

  globalAgentsMd = pkgs.writeText "antigravity-global-agents.md" ''
    # AGENTS.md — global agent rules (Antigravity, et al.)

    > Cross-repo, tool-neutral standards. Per-repo `AGENTS.md` / `CLAUDE.md`
    > override these. Managed declaratively from the NixOS flake — edit there,
    > not in the UI.

    ## Who I am working for

    A NixOS power user who manages everything declaratively in a git flake.
    **Home Manager is loaded as a flake module — never run `home-manager
    switch`; rebuild with `nixos-rebuild`.**

    ## Working style (PARR)

    Plan → Act → Reflect → Revise → Complete. Plan before acting, execute one
    step at a time, verify each checkpoint, never chain unverified commands,
    stop on the unexpected. Prefer small, reversible changes. Read existing
    code before modifying it.

    ## NixOS defaults

    - Feature-flag, module-based architecture. New services go in their own
      module behind a flag — never inline in a host's `configuration.nix`.
    - No `mkIf cond true` (assign `cond`). Explicit imports only. No bare URLs,
      minimal `with`/`rec`, no Import-From-Derivation.
    - Secrets at runtime only (agenix path/`*File` references) — never read a
      secret during evaluation.
    - New systemd services: `DynamicUser`, `ProtectSystem=strict`,
      `NoNewPrivileges`, `ProtectHome`.
    - Validate before deploying: `just validate` / `just test-host <host>`.

    ## Git

    Issue-driven: branch per change, Conventional Commits, PR with `Closes #N`,
    don't commit to `main` or merge untested.
  '';
in
{
  options.programs.antigravityConfig = {
    enable = lib.mkEnableOption "declarative Google Antigravity config bridge" // {
      default = true;
    };

    syncMcp = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Additively merge a small set of clean, secret-free stdio MCP servers
        into ~/.gemini/config/mcp_config.json. Existing servers always win;
        this only fills gaps and never removes anything.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # Global cross-tool rules — declaratively owned (edit in the flake, not the
    # Antigravity UI). Separate from GEMINI.md, which stays agent-managed.
    home.file.".gemini/AGENTS.md".source = globalAgentsMd;

    home.activation.antigravityMcpSync = lib.mkIf cfg.syncMcp (
      lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        cfgfile="${geminiDir}/config/mcp_config.json"
        shared="${sharedMcpFile}"
        mkdir -p "$(dirname "$cfgfile")"

        if [ ! -f "$cfgfile" ]; then
          $DRY_RUN_CMD install -m 0644 "$shared" "$cfgfile"
          $DRY_RUN_CMD echo "Antigravity: seeded mcp_config.json from shared MCP set"
        elif merged=$(${pkgs.jq}/bin/jq -s \
            '.[1] + {mcpServers: ((.[0].mcpServers // {}) + (.[1].mcpServers // {}))}' \
            "$shared" "$cfgfile" 2>/dev/null); then
          # Existing user servers (.[1]) win over shared (.[0]); only gaps filled.
          $DRY_RUN_CMD printf '%s\n' "$merged" > "$cfgfile"
          $DRY_RUN_CMD echo "Antigravity: synced shared MCP servers (existing preserved)"
        else
          $DRY_RUN_CMD echo "Antigravity: mcp_config.json not valid JSON — left untouched"
        fi
      ''
    );
  };
}
