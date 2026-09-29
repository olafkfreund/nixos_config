{ config, lib, pkgs, ... }:
let
  bin = "${config.home.profileDirectory}/bin";
  hookCmd = "${config.home.homeDirectory}/.local/bin/codex-nix-format";

  # Codex PostToolUse hook: format every .nix file an edit touched with
  # nix-format (#1983). apply_patch hands over patch text, not paths, so the
  # paths come from its "*** Add File:/Update File:/Move to:" headers; every
  # string in tool_input is scanned because the field layout is undocumented.
  codexNixFormat = pkgs.writeShellScript "codex-nix-format" ''
    payload="$(cat)"
    cwd="$(${pkgs.jq}/bin/jq -r '.cwd // empty' <<<"$payload" 2>/dev/null)"
    ${pkgs.jq}/bin/jq -r '(.tool_input.file_path // empty | "*** Update File: \(.)"),
                          ([.tool_input | .. | strings] | .[])' <<<"$payload" 2>/dev/null \
      | ${pkgs.gnused}/bin/sed -nE 's/^\*\*\* (Add File|Update File|Move to): (.*\.nix)$/\2/p' \
      | while IFS= read -r f; do
          case "$f" in /*) ;; *) f="''${cwd:-$PWD}/$f" ;; esac
          ${pkgs.customPkgs.nix-format}/bin/nix-format "$f"
        done
    exit 0
  '';

  # The guard that codex-implement relies on is a managed hook in
  # /etc/codex/requirements.toml (modules/programs/claude-code-managed.nix):
  # managed hooks need no /hooks trust, which user hooks do and silently skip
  # until they get it (#2081).
  codexImplement = pkgs.writeShellScriptBin "codex-implement" ''
    CODEX_CODER=1 exec "${bin}/codex" -p implement "$@"
  '';
in
{
  imports = [ ./codex-cli/module.nix ];

  programs.codex-cli = {
    enable = true;

    # `codex` is the real binary name from nixpkgs#codex. The rest are
    # convenience aliases so existing muscle memory keeps working.
    shellAliases = {
      ai-code = "codex";
      openai-codex = "codex";
      cx = "codex";
      code-ai = "codex";
      codex-project = "codex-project";
      cx-project = "codex-project";
      cx-analyze = "codex-project analyze";
      cx-ask = "codex-project ask";
    };
  };

  # Complementary dev tooling that pairs well with AI-assisted coding.
  # codex self-manages ~/.codex/config.toml, so Nix owns only whole files next
  # to it (implement.config.toml). The activation entries below only ADD what
  # is missing -- the nixd MCP server, the format and guard hooks, and
  # review_model -- and never rewrite what is there.
  home.packages = with pkgs; [
    prettier
    eslint
    python313Packages.black # Python formatter (pin py3.13 to match languages.nix/nvim.nix; bare `black` is py3.14 now and collides in home-manager-path)
    httpie # User-friendly HTTP client
    mcp-language-server # bridges nixd-agent to Codex as MCP tools (#1983)
    codexImplement
  ];

  # Stable path, so the hooks.json entry and Codex's trust hash survive rebuilds.
  home.file.".local/bin/codex-nix-format".source = codexNixFormat;

  # Implementation profile for `codex-implement` (#2081): write access, medium
  # reasoning, no network in the sandbox.
  home.file.".codex/implement.config.toml".text = ''
    # codex-implement profile (#2081): Sol, write access, guarded, no network.
    model = "gpt-6-sol"
    model_reasoning_effort = "medium"
    sandbox_mode = "workspace-write"
    approval_policy = "on-request"

    [sandbox_workspace_write]
    network_access = false
  '';

  # Never `exit` in an activation entry: they are concatenated into one script.
  home.activation = {
    codexNixdMcp = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if [ -x "${bin}/codex" ] && ! "${bin}/codex" mcp get nixd >/dev/null 2>&1; then
        $DRY_RUN_CMD "${bin}/codex" mcp add nixd -- \
          "${bin}/mcp-language-server" --workspace . --lsp "${bin}/nixd-agent"
      fi
    '';

    codexNixFormatHook = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      hooks="$HOME/.codex/hooks.json"
      if [ -d "$HOME/.codex" ]; then
        tmp="$(mktemp)"
        { [ -s "$hooks" ] && cat "$hooks" || echo '{}'; } | ${pkgs.jq}/bin/jq --arg cmd "${hookCmd}" '
          .hooks.PostToolUse //= []
          | if any(.hooks.PostToolUse[].hooks[]?; .command == $cmd) then .
            else .hooks.PostToolUse += [{ matcher: "apply_patch|Edit|Write",
                   hooks: [{ type: "command", command: $cmd, timeout: 30 }] }]
            end' > "$tmp" || true
        if [ -s "$tmp" ] && ! ${pkgs.diffutils}/bin/cmp -s "$tmp" "$hooks"; then
          $DRY_RUN_CMD install -m 0644 "$tmp" "$hooks"
        fi
        rm -f "$tmp"
      fi
    '';

    codexReviewModel = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      config="$HOME/.codex/config.toml"
      if [ -f "$config" ] && ! grep -q '^review_model' "$config"; then
        tmp="$(mktemp)"
        { echo 'review_model = "gpt-6-astra"'; cat "$config"; } > "$tmp"
        $DRY_RUN_CMD install -m 0600 "$tmp" "$config"
        rm -f "$tmp"
      fi
    '';
  };
}
