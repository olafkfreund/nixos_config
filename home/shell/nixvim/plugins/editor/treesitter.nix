{
  pkgs,
  lib,
  ...
}: {
  programs.nixvim = {
    plugins = {
      treesitter = {
        enable = true;
        ensureInstalled = "all";

        incrementalSelection = {
          enable = true;
          keymaps = {
            initSelection = "<CR>";
            nodeIncremental = "<CR>";
            nodeDecremental = "<BS>";
            scopeIncremental = "<TAB>";
          };
        };

        indent = true;

        folding = true;

        nixvimInjections = true;
      };

      treesitter-refactor = {
        enable = true;
        highlightDefinitions = {
          enable = true;
          clearOnCursorMove = true;
        };
        navigation = {
          enable = true;
          keymaps = {
            gotoDefinition = "gnd";
            listDefinitions = "gnD";
            listDefinitionsTab = "gO";
            gotoPreviousUsage = "<A-*>";
            gotoNextUsage = "<A-#>";
          };
        };
        smartRename = {
          enable = true;
          keymaps = {
            smartRename = "grr";
          };
        };
      };

      treesitter-textobjects = {
        enable = true;
        select = {
          enable = true;
          lookahead = true;
          keymaps = {
            "af" = "@function.outer";
            "if" = "@function.inner";
            "ac" = "@class.outer";
            "ic" = "@class.inner";
            "aa" = "@parameter.outer";
            "ia" = "@parameter.inner";
          };
        };
        move = {
          enable = true;
          setJumps = true;
          gotoNextStart = {
            "]m" = "@function.outer";
            "]]" = "@class.outer";
          };
          gotoNextEnd = {
            "]M" = "@function.outer";
            "][" = "@class.outer";
          };
          gotoPreviousStart = {
            "[m" = "@function.outer";
            "[[" = "@class.outer";
          };
          gotoPreviousEnd = {
            "[M" = "@function.outer";
            "[]" = "@class.outer";
          };
        };
      };
    };
  };
}
