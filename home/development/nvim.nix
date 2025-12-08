# Enhanced Neovim System Packages
# Provides development tools for LazyVim without configuration conflicts
{ lib
, config
, pkgs
, ...
}:
with lib; let
  cfg = config.editor.neovim;

  # Enhanced package support for LazyVim
  languageSupport = {
    # Core language servers (for LazyVim to use)
    lsp = [
      pkgs.nixd # Nix LSP
      pkgs.lua-language-server # Lua LSP
      pkgs.nodePackages.typescript-language-server # TS/JS LSP
      pkgs.python313Packages.python-lsp-server # Python LSP
      pkgs.gopls # Go LSP
      pkgs.rust-analyzer # Rust LSP
    ];

    # Formatters (for LazyVim formatters)
    formatters = [
      pkgs.alejandra # Nix formatter
      pkgs.stylua # Lua formatter
      pkgs.nodePackages.prettier # JS/TS formatter
      pkgs.python313Packages.black # Python formatter
      pkgs.python313Packages.isort # Python import sorter
      pkgs.go # Go (includes gofmt)
      pkgs.rustfmt # Rust formatter
    ];

    # Development tools
    tools = [
      pkgs.ripgrep # For telescope search
      pkgs.fd # For telescope file finding
      pkgs.git # Git integration
      pkgs.lazygit # LazyGit integration
      pkgs.tree-sitter # Syntax highlighting
      pkgs.curl # For plugin installation
      pkgs.unzip # For plugin extraction
      pkgs.wget # For downloads
      pkgs.gcc # For native compilation

      # Essential Lua/Ruby dependencies for Neovim
      pkgs.luajitPackages.lpeg # LPeg for parsing
      pkgs.luajitPackages.luabitop # Bitwise operations
      pkgs.luajitPackages.mpack # MessagePack for Neovim RPC
      pkgs.libuv # libuv (libluv dependency)
      pkgs.unibilium # Terminal info library

      # Ruby gems for Neovim
      pkgs.ruby_3_3 # Ruby 3.3 interpreter

      # Additional Python dependencies
      pkgs.python313Packages.tomlkit # TOML parsing for Python
    ];

    # AI tools (for LazyVim AI plugins)
    ai = [
      pkgs.codeium # Codeium support
    ];

    # Note: LazyVim manages plugins itself, so we don't install them via Nix
    # to avoid package conflicts and let LazyVim handle version management
  };
in
{
  options.editor.neovim = {
    enable = mkEnableOption {
      default = false;
      description = "neovim";
    };
  };
  config = mkIf cfg.enable {
    # Home configuration block
    home = {
      # LazyVim-compatible system package support
      # Provides tools without conflicting with LazyVim configuration
      packages = flatten [
        # Ruby support for Neovim (Neovim installed via programs.neovim below)
        [
          pkgs.ruby # Ruby interpreter for Neovim plugins
        ]

        # Tree-sitter (LazyVim will install grammars as needed)
        [
          pkgs.tree-sitter # Core tree-sitter for syntax highlighting
        ]

        # LazyVim supporting packages
        languageSupport.lsp
        languageSupport.formatters
        languageSupport.tools
        languageSupport.ai
      ];

      # Environment variables for LazyVim integration
      sessionVariables = {
        # Make LSP servers available to LazyVim
        NIXD_PATH = "${pkgs.nixd}/bin/nixd";
        RUST_ANALYZER_PATH = "${pkgs.rust-analyzer}/bin/rust-analyzer";
        GOPLS_PATH = "${pkgs.gopls}/bin/gopls";
        TYPESCRIPT_LANGUAGE_SERVER_PATH = "${pkgs.nodePackages.typescript-language-server}/bin/typescript-language-server";
        PYLSP_PATH = "${pkgs.python313Packages.python-lsp-server}/bin/pylsp";
        LUA_LANGUAGE_SERVER_PATH = "${pkgs.lua-language-server}/bin/lua-language-server";

        # Make formatters available to LazyVim
        ALEJANDRA_PATH = "${pkgs.alejandra}/bin/alejandra";
        STYLUA_PATH = "${pkgs.stylua}/bin/stylua";
        PRETTIER_PATH = "${pkgs.nodePackages.prettier}/bin/prettier";
        BLACK_PATH = "${pkgs.python313Packages.black}/bin/black";
        ISORT_PATH = "${pkgs.python313Packages.isort}/bin/isort";
      };

      # Shell aliases for development workflow (compatible with LazyVim)
      shellAliases = {
        # LazyVim aliases
        lv = "nvim";
        lazyvim = "nvim";

        # Development shortcuts
        nix-fmt = "alejandra";
        py-fmt = "black";
        py-isort = "isort";
        js-fmt = "prettier --write";
        lua-fmt = "stylua";

        # Git shortcuts for LazyVim integration
        # Note: lg function defined in shell config for advanced lazygit integration
        gst = "git status";
      };
    };

    # Configure Neovim program
    programs.neovim = {
      enable = true;
      defaultEditor = true;
      viAlias = true;
      vimAlias = true;
    };

    # XDG configuration for LazyVim
    xdg.configFile = {
      # Create a development environment info file for LazyVim to reference
      "nvim/lua/config/nix-env.lua".text = ''
        -- NixOS Development Environment Information
        -- This file provides paths for LazyVim to use system-provided tools

        local M = {}

        -- LSP server paths (provided by Nix)
        M.lsp_paths = {
          nixd = "${pkgs.nixd}/bin/nixd",
          rust_analyzer = "${pkgs.rust-analyzer}/bin/rust-analyzer",
          gopls = "${pkgs.gopls}/bin/gopls",
          tsserver = "${pkgs.nodePackages.typescript-language-server}/bin/typescript-language-server",
          pylsp = "${pkgs.python313Packages.python-lsp-server}/bin/pylsp",
          lua_ls = "${pkgs.lua-language-server}/bin/lua-language-server",
        }

        -- Formatter paths (provided by Nix)
        M.formatter_paths = {
          alejandra = "${pkgs.alejandra}/bin/alejandra",
          stylua = "${pkgs.stylua}/bin/stylua",
          prettier = "${pkgs.nodePackages.prettier}/bin/prettier",
          black = "${pkgs.python313Packages.black}/bin/black",
          isort = "${pkgs.python313Packages.isort}/bin/isort",
        }

        -- Development tools (provided by Nix)
        M.tool_paths = {
          ripgrep = "${pkgs.ripgrep}/bin/rg",
          fd = "${pkgs.fd}/bin/fd",
          lazygit = "${pkgs.lazygit}/bin/lazygit",
        }

        return M
      '';
    };
  };
}
