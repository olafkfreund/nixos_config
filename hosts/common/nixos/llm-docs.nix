# llm-docs (#3022): a private-tier llm-index client that can only reach a local model.
# opencode runs in a bubblewrap sandbox with loopback only; a filtering proxy outside
# is its sole way out, and only to the pinned local Ollama model.
{ config, lib, inputs, ... }:
let
  cfg = config.local.llmIndex.privateClient;
in
{
  options.local.llmIndex.privateClient.enable =
    lib.mkEnableOption "llm-docs, the private llm-index client (local model only)";

  config = lib.mkIf cfg.enable {
    home-manager.users.olafkfreund =
      { config, lib, pkgs, ... }:
      let
        MODEL = "qwen3.8:27b";
        home = config.home.homeDirectory;
        llmIndex = config.services.llm-index;
        opencode = "${inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.opencode-bin}/bin/opencode";

        proxy = pkgs.writers.writePython3Bin "llm-docs-proxy" { flakeIgnore = [ "E501" "E265" "W503" ]; }
          (builtins.readFile ./llm-docs-proxy.py);

        # opencode's `instructions` takes file paths, so the text goes through the store
        instructionsFile = pkgs.writeText "llm-docs-instructions.md" llmIndex.agentInstructions;

        opencodeConfig = builtins.toJSON {
          provider.ollama = {
            npm = "@ai-sdk/openai-compatible";
            name = "Ollama (local)";
            options.baseURL = "http://127.0.0.1:11434/v1";
            models.${MODEL}.name = MODEL;
          };
          model = "ollama/${MODEL}";
          small_model = "ollama/${MODEL}";
          experimental.policies = [
            { action = "provider.use"; resource = "*"; effect = "deny"; }
            { action = "provider.use"; resource = "ollama"; effect = "allow"; }
          ];
          mcp.private = {
            type = "local";
            command = [
              "${llmIndex.package}/bin/llm-index"
              "mcp"
              "--tier"
              "private"
              "--config"
              "${home}/.config/llm-index/config.toml"
            ];
          };
          permission = {
            "*" = "deny";
            private_search = "allow";
            private_get = "allow";
            private_recent = "allow";
            private_status = "allow";
          };
          share = "disabled";
          autoupdate = false;
          snapshot = false;
          plugin = [ ];
          instructions = [ "${instructionsFile}" ];
        };

        closeFds = ''
          for f in /proc/self/fd/*; do n=''${f##*/}; [ "$n" -gt 2 ] && eval "exec $n>&-"; done 2>/dev/null || true
        '';

        # runs inside the sandbox: bridge 127.0.0.1:11434 to the proxy socket, then exec "$@"
        inner = pkgs.writeShellScript "llm-docs-inner" ''
          ${pkgs.socat}/bin/socat TCP-LISTEN:11434,bind=127.0.0.1,fork,reuseaddr UNIX-CONNECT:/run/llm-docs.sock &
          up=0
          for _ in $(seq 1 50); do
            if (exec 3<>/dev/tcp/127.0.0.1/11434) 2>/dev/null; then up=1; break; fi
            ${pkgs.coreutils}/bin/sleep 0.1
          done
          if [ "$up" != 1 ]; then echo "llm-docs: bridge did not come up" >&2; exit 1; fi
          ${closeFds}
          exec "$@"
        '';

        state = "${home}/.local/state/llm-index";
        share = "${home}/.local/share/llm-docs";
        stateFiles = [ "private.db" "private.db-wal" "private.db-shm" "public.db" "public.db-wal" "public.db-shm" ];

        # the one sandbox definition, shared by llm-docs and llm-docs-diag
        bwrapArgs = [
          "--unshare-all"
          "--die-with-parent"
          "--clearenv"
          "--chdir"
          home
          "--ro-bind"
          "/nix/store"
          "/nix/store"
          "--ro-bind"
          "/lib64"
          "/lib64"
          "--ro-bind"
          "/run/current-system/sw/share/nix-ld"
          "/run/current-system/sw/share/nix-ld"
          "--ro-bind"
          "/etc/passwd"
          "/etc/passwd"
          "--ro-bind"
          "/etc/group"
          "/etc/group"
          "--ro-bind"
          "/etc/nsswitch.conf"
          "/etc/nsswitch.conf"
          "--ro-bind"
          "/etc/localtime"
          "/etc/localtime"
          "--proc"
          "/proc"
          "--dev"
          "/dev"
          "--tmpfs"
          "/tmp"
          "--tmpfs"
          "/home"
          "--ro-bind"
          "${home}/.config/llm-index/config.toml"
          "${home}/.config/llm-index/config.toml"
        ]
        ++ lib.concatMap (f: [ "--ro-bind" "${state}/${f}" "${state}/${f}" ]) stateFiles
        ++ [
          "--bind"
          "${share}/data"
          "${home}/.local/share/opencode"
          "--bind"
          "${share}/config"
          "${home}/.config/opencode"
          "--bind"
          "${share}/cache"
          "${home}/.cache/opencode"
        ];

        env = {
          HOME = home;
          PATH = lib.makeBinPath [ pkgs.coreutils ];
          OPENCODE_CONFIG_CONTENT = opencodeConfig;
          OPENCODE_DISABLE_PROJECT_CONFIG = "1";
          OPENCODE_DISABLE_AUTOUPDATE = "1";
          OPENCODE_DISABLE_SHARE = "1";
          OPENCODE_DISABLE_MODELS_FETCH = "1";
          OPENCODE_DISABLE_DEFAULT_PLUGINS = "1";
          OPENCODE_DISABLE_CLAUDE_CODE = "1";
          OPENCODE_DISABLE_EXTERNAL_SKILLS = "1";
          OPENCODE_DISABLE_LSP_DOWNLOAD = "1";
        };
        setenvArgs = lib.concatLists (lib.mapAttrsToList (k: v: [ "--setenv" k v ]) env);

        # $@ is the command to run inside; the caller prepares its own arguments
        mkLauncher = name: preamble: pkgs.writeShellApplication {
          inherit name;
          runtimeInputs = [ pkgs.bubblewrap pkgs.coreutils ];
          text = ''
            ${preamble}
            if [ "$(cat /proc/sys/dev/tty/legacy_tiocsti)" != 0 ]; then
              echo "${name}: dev.tty.legacy_tiocsti must be 0" >&2
              exit 1
            fi
            run="''${XDG_RUNTIME_DIR:?}/llm-docs"
            install -d -m 0700 "$run" "${share}"
            install -d -m 0700 "${share}/data" "${share}/config" "${share}/cache"
            # its log (method, path, model, status; never bodies) stays out of the TUI
            ${proxy}/bin/llm-docs-proxy --socket "$run/ollama.sock" --model ${lib.escapeShellArg MODEL} 2>>"$run/proxy.log" &
            proxy_pid=$!
            trap 'kill "$proxy_pid" 2>/dev/null || true' EXIT
            for _ in $(seq 1 50); do
              [ -S "$run/ollama.sock" ] && break
              sleep 0.1
            done
            [ -S "$run/ollama.sock" ] || { echo "${name}: proxy did not start" >&2; exit 1; }
            ${closeFds}
            bwrap_args=(
              ${lib.escapeShellArgs bwrapArgs}
              --bind "$run/ollama.sock" /run/llm-docs.sock
              ${lib.escapeShellArgs setenvArgs}
              --setenv TERM "''${TERM:-xterm}"
              --setenv COLORTERM "''${COLORTERM:-}"
              --setenv LANG "''${LANG:-C.UTF-8}"
            )
            bwrap "''${bwrap_args[@]}" ${inner} "''${cmd[@]}"
          '';
        };

        llm-docs = mkLauncher "llm-docs" ''
          case "$#" in
            0) cmd=(${opencode}) ;;
            2) if [ "$1" = run ]; then cmd=(${opencode} run "$2"); else echo "usage: llm-docs [run <prompt>]" >&2; exit 2; fi ;;
            *) echo "usage: llm-docs [run <prompt>]" >&2; exit 2 ;;
          esac
        '';

        diag = mkLauncher "llm-docs-diag" ''
          [ "$#" -gt 0 ] || { echo "usage: llm-docs-diag <cmd...>" >&2; exit 2; }
          cmd=("$@")
        '';
      in
      {
        options.local.llmDocs.diag = lib.mkOption {
          type = lib.types.package;
          readOnly = true;
          default = diag;
          description = "Runs a command in the llm-docs sandbox; for live checks, not on PATH.";
        };

        config.home.packages = [ llm-docs ];
      };
  };
}
