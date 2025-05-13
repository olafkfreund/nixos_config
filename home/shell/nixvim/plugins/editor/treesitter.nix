{
  config,
  lib,
  pkgs,
  ...
}: {
  programs.nixvim = {
    plugins.treesitter = {
      enable = true;

      # Automatically install missing parsers
      ensureInstalled = [
        "bash"
        "c"
        "cmake"
        "cpp"
        "css"
        "dockerfile"
        "go"
        "gomod"
        "html"
        "javascript"
        "json"
        "lua"
        "make"
        "markdown"
        "markdown_inline"
        "nix"
        "python"
        "regex"
        "rust"
        "toml"
        "tsx"
        "typescript"
        "vim"
        "yaml"
      ];

      # Install all maintained parsers
      grammarPackages = pkgs.vimPlugins.nvim-treesitter.allGrammars;

      incrementalSelection = {
        enable = true;
        keymaps = {
          initSelection = "<C-space>";
          nodeIncremental = "<C-space>";
          nodeDecremental = "<bs>";
          scopeIncremental = "<C-s>";
        };
      };

      # Enable indentation support
      indent = true;

      # Enable folding with treesitter
      folding = true;

      # Additional modules
      moduleConfig = {
        highlight = {
          enable = true;
          additionalVimRegexHighlighting = false;
        };

        autotag = {
          enable = true;
        };

        rainbow = {
          enable = true;
          extendedMode = true;
          maxFileLines = 1000;
        };
      };
    };

    # Configure treesitter context for showing code context
    plugins.treesitter-context = {
      enable = true;
      maxLines = 3;
      minWindowHeight = 20;
      mode = "cursor";
    };
  };
}
