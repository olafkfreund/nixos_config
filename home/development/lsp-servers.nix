# Comprehensive LSP Server Configuration for Claude Code
# All 11+ language servers supported by Claude Code LSP (v2.0.74+)
# Reference: https://www.aifreeapi.com/en/posts/claude-code-lsp

{ pkgs, lib, ... }:
with lib;
{
  home.packages = with pkgs; [
      # === CLAUDE CODE SUPPORTED LSP SERVERS (11 Languages) ===

      # 1. Python - Pyright (Claude Code: pyright@claude-code-lsps)
      pyright

      # 2. TypeScript/JavaScript - vtsls (Claude Code: vtsls@claude-code-lsps)
      vtsls
      nodePackages.typescript
      typescript-language-server

      # 3. Go - gopls (Claude Code: gopls@claude-code-lsps)
      gopls
      go
      delve
      gore
      gotests

      # 4. Rust - rust-analyzer (Claude Code: rust-analyzer@claude-code-lsps)
      rust-analyzer
      cargo
      rustc
      clippy
      rustfmt

      # 5. Java - jdtls (Claude Code: jdtls@claude-code-lsps)
      jdt-language-server

      # 6. C/C++ - clangd (Claude Code: clangd@claude-code-lsps)
      clang-tools # Includes clangd
      cmake
      gcc

      # 7. C# - OmniSharp (Claude Code: omnisharp@claude-code-lsps)
      omnisharp-roslyn

      # 8. PHP - Intelephense (Claude Code: intelephense@claude-code-lsps)
      nodePackages.intelephense

      # 9. Kotlin - kotlin-language-server (Claude Code: kotlin-language-server@claude-code-lsps)
      kotlin-language-server

      # 10. Ruby - Solargraph (Claude Code: solargraph@claude-code-lsps)
      rubyPackages.solargraph

      # 11. HTML/CSS/JSON - vscode-langservers (Claude Code: vscode-html-css@claude-code-lsps)
      nodePackages.vscode-langservers-extracted

      # === ADDITIONAL IMPORTANT LSP SERVERS ===

      # Nix - nil (faster, more modern) AND nixd (feature-rich)
      nil
      nixd

      # Terraform - terraform-ls
      terraform-ls

      # YAML - yaml-language-server
      nodePackages.yaml-language-server

      # Bash - bash-language-server
      nodePackages.bash-language-server

      # Docker - dockerfile-language-server
      dockerfile-language-server

      # Markdown - marksman
      marksman

      # JSON - vscode-json-languageserver (included in vscode-langservers-extracted above)

      # SQL - sqls
      sqls

      # === FORMATTERS AND LINTERS ===

      # Python formatters
      python313Packages.black
      python313Packages.isort
      python313Packages.flake8
      python313Packages.mypy
      ruff # Modern Python linter/formatter

      # JavaScript/TypeScript formatters
      nodePackages.prettier
      nodePackages.eslint

      # Nix formatters
      alejandra
      nixpkgs-fmt
      nixfmt-rfc-style
      deadnix
      statix

      # Go formatters
      gofumpt # Better gofmt
      goimports-reviser

      # Rust formatters (rustfmt included in rust-analyzer)

      # Java formatters
      google-java-format

      # C/C++ formatters
      clang-tools # Includes clang-format

      # YAML/JSON formatters
      yamlfmt

      # Markdown formatters
      mdformat

      # === DEVELOPMENT TOOLS ===

      # Code navigation and analysis
      universal-ctags

      # Performance profilers
      valgrind

      # Debugging tools
      gdb
      lldb
  ];

  # Environment variables for LSP servers
  home.sessionVariables = {
      # Enable Claude Code LSP support
      ENABLE_LSP_TOOLS = "1";

      # Go paths
      GOPATH = "$HOME/go";
      GOBIN = "$HOME/go/bin";

      # Rust paths
      CARGO_HOME = "$HOME/.cargo";
      RUSTUP_HOME = "$HOME/.rustup";

    # Python optimization
    PYTHONDONTWRITEBYTECODE = "1";
    PYTHONUNBUFFERED = "1";
  };

  # LSP server configuration file for editors to reference
  home.file.".config/lsp-servers/config.json".text = builtins.toJSON {
      servers = {
        # Claude Code supported servers
        pyright = {
          command = "${pkgs.pyright}/bin/pyright-langserver";
          args = [ "--stdio" ];
          filetypes = [ "python" ];
          root_patterns = [ "pyproject.toml" "setup.py" "requirements.txt" ];
        };

        vtsls = {
          command = "${pkgs.vtsls}/bin/vtsls";
          args = [ "--stdio" ];
          filetypes = [ "javascript" "javascriptreact" "typescript" "typescriptreact" ];
          root_patterns = [ "package.json" "tsconfig.json" "jsconfig.json" ];
        };

        gopls = {
          command = "${pkgs.gopls}/bin/gopls";
          args = [ ];
          filetypes = [ "go" "gomod" "gowork" "gotmpl" ];
          root_patterns = [ "go.mod" "go.work" ];
        };

        rust_analyzer = {
          command = "${pkgs.rust-analyzer}/bin/rust-analyzer";
          args = [ ];
          filetypes = [ "rust" ];
          root_patterns = [ "Cargo.toml" "Cargo.lock" ];
        };

        jdtls = {
          command = "${pkgs.jdt-language-server}/bin/jdtls";
          args = [ ];
          filetypes = [ "java" ];
          root_patterns = [ "build.gradle" "pom.xml" ];
        };

        clangd = {
          command = "${pkgs.clang-tools}/bin/clangd";
          args = [ "--background-index" ];
          filetypes = [ "c" "cpp" "objc" "objcpp" "cuda" ];
          root_patterns = [ "compile_commands.json" ".git" ];
        };

        omnisharp = {
          command = "${pkgs.omnisharp-roslyn}/bin/OmniSharp";
          args = [ "--languageserver" "--hostPID" "$PPID" ];
          filetypes = [ "cs" ];
          root_patterns = [ "*.sln" "*.csproj" ];
        };

        intelephense = {
          command = "${pkgs.nodePackages.intelephense}/bin/intelephense";
          args = [ "--stdio" ];
          filetypes = [ "php" ];
          root_patterns = [ "composer.json" ".git" ];
        };

        kotlin_language_server = {
          command = "${pkgs.kotlin-language-server}/bin/kotlin-language-server";
          args = [ ];
          filetypes = [ "kotlin" ];
          root_patterns = [ "build.gradle.kts" "settings.gradle.kts" ];
        };

        solargraph = {
          command = "${pkgs.rubyPackages.solargraph}/bin/solargraph";
          args = [ "stdio" ];
          filetypes = [ "ruby" ];
          root_patterns = [ "Gemfile" ".git" ];
        };

        html = {
          command = "${pkgs.nodePackages.vscode-langservers-extracted}/bin/vscode-html-language-server";
          args = [ "--stdio" ];
          filetypes = [ "html" ];
        };

        cssls = {
          command = "${pkgs.nodePackages.vscode-langservers-extracted}/bin/vscode-css-language-server";
          args = [ "--stdio" ];
          filetypes = [ "css" "scss" "less" ];
        };

        # Additional important servers
        nil_ls = {
          command = "${pkgs.nil}/bin/nil";
          args = [ ];
          filetypes = [ "nix" ];
          root_patterns = [ "flake.nix" "default.nix" ];
        };

        nixd = {
          command = "${pkgs.nixd}/bin/nixd";
          args = [ ];
          filetypes = [ "nix" ];
          root_patterns = [ "flake.nix" "default.nix" ];
        };

        terraform_ls = {
          command = "${pkgs.terraform-ls}/bin/terraform-ls";
          args = [ "serve" ];
          filetypes = [ "terraform" "tf" ];
          root_patterns = [ ".terraform" "terraform.tfvars" ];
        };

        yamlls = {
          command = "${pkgs.nodePackages.yaml-language-server}/bin/yaml-language-server";
          args = [ "--stdio" ];
          filetypes = [ "yaml" "yml" ];
        };

        bashls = {
          command = "${pkgs.nodePackages.bash-language-server}/bin/bash-language-server";
          args = [ "start" ];
          filetypes = [ "sh" "bash" ];
        };

        dockerls = {
          command = "${pkgs.dockerfile-language-server}/bin/docker-langserver";
          args = [ "--stdio" ];
          filetypes = [ "dockerfile" ];
        };

      marksman = {
        command = "${pkgs.marksman}/bin/marksman";
        args = [ "server" ];
        filetypes = [ "markdown" ];
      };
    };
  };
}
