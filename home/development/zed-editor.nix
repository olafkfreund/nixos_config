{ config
, lib
, pkgs
, ...
}:
# Zed — GPU-accelerated editor, used here as the AI-assisted counterpart to
# neovim. Configured for this repo's actual stack: Nix first, then the
# container/k8s/justfile tooling the hosts are built with.
#
# LLM integration deliberately carries NO credentials. Zed's Agent Panel can
# drive Claude through the Agent Client Protocol, and an ACP agent "owns its
# own authentication" — it reuses the already-authenticated `claude` binary
# (pkgs.claude-code-native, on p620 and razer). Nothing needs an API key in
# settings.json, which matters because settings.json lands in the world-
# readable Nix store. `secrets/api-anthropic.age` exists if you ever want
# Zed's *built-in* Anthropic provider instead, but that key must be delivered
# at runtime via the environment — never written into userSettings.
let
  inherit (lib) mkIf mkEnableOption;
  cfg = config.editor.zed;
in
{
  options.editor.zed = {
    enable = mkEnableOption "Zed editor with Nix + LLM tooling";
  };

  config = mkIf cfg.enable {
    programs.zed-editor = {
      enable = true;
      package = pkgs.zed-editor;

      # Written to settings.json as `auto_install_extensions`; Zed pulls these
      # on first launch. Every name verified against the zed-industries/
      # extensions tree (1358 entries) — a typo here silently no-ops.
      extensions = [
        "nix" # the point of the exercise
        "toml" # flake/cargo/config files
        "dockerfile"
        "docker-compose"
        "helm" # k3d/factory manifests
        "terraform"
        "just" # this repo is driven by a justfile
        "make"
        "sql"
        "env"
        "log" # journal/service logs
        "lua" # neovim config
        "git-firefly" # inline blame
      ];

      # Zed resolves language servers and formatters from its own PATH, so
      # they must be listed here even though lsp-servers.nix already puts them
      # in the user profile.
      extraPackages = with pkgs; [
        nixd # Nix LSP (evaluates, so it understands this flake)
        nil # fallback Nix LSP
        alejandra # Nix formatter
        bash-language-server
        shfmt
        taplo # TOML
        yaml-language-server
        marksman # Markdown
      ];

      userSettings = {
        # Zed phones home by default.
        telemetry = {
          diagnostics = false;
          metrics = false;
        };

        # No `theme` here: stylix's own zed target (modules/zed/hm.nix) sets
        # a Base16 theme name, generated from the base16 scheme in
        # shared-variables.nix. Defining it here is a duplicate-definition
        # error, and overriding it would fight stylix — the same mistake the
        # niri and GNOME modules already document.

        format_on_save = "on";
        ensure_final_newline_on_save = true;
        remove_trailing_whitespace_on_save = true;

        terminal.shell.program = "${pkgs.zsh}/bin/zsh";

        # nixd over nil: nixd evaluates the flake, so completion and go-to-def
        # work across our own modules and options rather than just parsing.
        lsp.nixd.settings = {
          nixpkgs.expr = "import <nixpkgs> { }";
          formatting.command = [ "alejandra" ];
        };

        languages.Nix = {
          language_servers = [ "nixd" "!nil" ];
          formatter.external = {
            command = "${pkgs.alejandra}/bin/alejandra";
            arguments = [ "--quiet" "--" ];
          };
          tab_size = 2;
        };

        # Agent Panel. No provider credentials here on purpose — add Claude
        # via the Agent Panel's ACP registry and it will reuse the `claude`
        # CLI's existing login.
        agent = {
          enabled = true;
          button = true;
          default_profile = "ask";
        };

        # Ships a bundled Node purely for extensions; we already have one.
        node = {
          path = lib.mkDefault "${pkgs.nodejs}/bin/node";
          npm_path = lib.mkDefault "${pkgs.nodejs}/bin/npm";
        };

        vim_mode = false;
        load_direnv = "shell_hook";
      };
    };
  };
}
