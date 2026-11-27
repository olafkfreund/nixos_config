{ config, lib, pkgs, ... }:
let
  bin = "${config.home.profileDirectory}/bin";
  hookCmd = "${config.home.homeDirectory}/.local/bin/codex-nix-format";
  team = import ../../modules/programs/agent-team.nix;

  # Appended after a profile's root keys (#3263).
  agentsTable = ''

    [agents]
    max_threads = ${toString team.limits.subagents}
    max_depth = ${toString team.limits.depth}
  '';

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
    req=/etc/codex/requirements.toml
    guard=/etc/codex/hooks/coder-guard
    q='[.hooks.PreToolUse[].hooks[] | select(.command == "/etc/codex/hooks/coder-guard")] | length'
    n=$(${pkgs.yq-go}/bin/yq -p toml -o json "$q" "$req" 2>/dev/null)
    if [ ! -x "$guard" ] || ! [ "$n" -ge 1 ] 2>/dev/null; then
      echo "codex-implement: $req does not register $guard -- refusing to run (#2757)." >&2
      exit 1
    fi
    exec env -u OPENAI_API_KEY -u OPENAI_API_KEY_FILE -u GEMINI_API_KEY -u GEMINI_API_KEY_FILE \
      -u GOOGLE_API_KEY -u ANTHROPIC_API_KEY -u ANTHROPIC_API_KEY_FILE CODEX_CODER=1 "${bin}/codex" \
      --dangerously-bypass-approvals-and-sandbox -c forced_login_method=chatgpt -p implement "$@"
  '';
in
{
  imports = [ ./codex-cli/module.nix ];

  programs.codex-cli = {
    enable = true;

    # `codex` is the real binary name (pkgs.codex, see overlays/custom-packages.nix). The rest are
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
      codex-manager = "codex -p manager";
    };
  };

  # Complementary dev tooling that pairs well with AI-assisted coding.
  # Codex owns ~/.codex/config.toml; activation edits its root keys in place.
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

  # Implementation profile for `codex-implement` (#2081): the worker role (#3263).
  home.file.".codex/implement.config.toml".text = ''
    # codex-implement profile (#2081): the launcher overrides sandbox and approval.
    model = "${team.roles.worker.codex.model}"
    model_reasoning_effort = "${team.roles.worker.codex.effort}"
    sandbox_mode = "danger-full-access"
    approval_policy = "never"
  '' + agentsTable;

  home.file.".codex/manager.config.toml".text = ''
    # codex-manager profile (#3263).
    model = "${team.roles.manager.codex.model}"
    model_reasoning_effort = "${team.roles.manager.codex.effort}"
    review_model = "${team.roles.reviewer.codex.model}"
  '' + agentsTable;

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

    # Force the root review_model to the reviewer role; write only what parses (#3263).
    codexReviewModel = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      config="$HOME/.codex/config.toml"
      if [ -f "$config" ]; then
        tmp="$(mktemp)"
        ${pkgs.gawk}/bin/awk '
          /^[[:space:]]*\[/ { table = 1 }
          !table && /^[[:space:]]*"?review_model"?[[:space:]]*=/ {
            found = 1; $0 = "review_model = \"${team.roles.reviewer.codex.model}\""
          }
          { lines[NR] = $0 }
          END {
            if (!found) print "review_model = \"${team.roles.reviewer.codex.model}\""
            for (i = 1; i <= NR; i++) print lines[i]
          }
        ' "$config" > "$tmp"
        if ! ${pkgs.diffutils}/bin/cmp -s "$tmp" "$config"; then
          if ${pkgs.python3}/bin/python3 -c 'import sys,tomllib; tomllib.load(open(sys.argv[1],"rb"))' "$tmp" 2>/dev/null; then
            $DRY_RUN_CMD install -m 0600 "$tmp" "$config"
          else
            echo "codexReviewModel: $config would not parse with the new review_model, left unchanged" >&2
          fi
        fi
        rm -f "$tmp"
      fi
    '';

    codexUnrestricted = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      config="$HOME/.codex/config.toml"
      if [ -f "$config" ]; then
        tmp="$(mktemp)"
        ${pkgs.gawk}/bin/awk '
          /^\[\[?[^]=]+\]\]?[[:space:]]*(#.*)?$/ { table = 1 }
          !table && /^[[:space:]]*approval_policy[[:space:]]*=/ {
            approval = 1; $0 = "approval_policy = \"never\""
          }
          !table && /^[[:space:]]*sandbox_mode[[:space:]]*=/ {
            sandbox = 1; $0 = "sandbox_mode = \"danger-full-access\""
          }
          { lines[NR] = $0 }
          END {
            if (!approval) print "approval_policy = \"never\""
            if (!sandbox) print "sandbox_mode = \"danger-full-access\""
            for (i = 1; i <= NR; i++) print lines[i]
          }
        ' "$config" > "$tmp"
        if ! ${pkgs.diffutils}/bin/cmp -s "$tmp" "$config"; then
          backup="$HOME/.codex/.pre-2812-root-keys"
          if [ ! -e "$backup" ]; then
            old="$(mktemp)"
            ${pkgs.gawk}/bin/awk '
              /^\[\[?[^]=]+\]\]?[[:space:]]*(#.*)?$/ { table = 1 }
              !table && /^[[:space:]]*(approval_policy|sandbox_mode)[[:space:]]*=/ { print }
            ' "$config" > "$old"
            $DRY_RUN_CMD install -m 0600 "$old" "$backup"
            rm -f "$old"
          fi
          $DRY_RUN_CMD install -m 0600 "$tmp" "$config"
        fi
        rm -f "$tmp"
      fi
    '';
  };
}
