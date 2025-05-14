{
  pkgs,
  lib,
  ...
}: {
  imports = [
    ./core
    ./editor
    ./ui
    ./coding
    ./lang
    ./plugins/default.nix
  ];

  programs.nixvim = {
    plugins = {
      treesitter = {
        enable = true;
        ensureInstalled = "all";
      };

      telescope = {
        enable = true;
        defaults = {
          file_ignore_patterns = [
            "^.git/"
            "^.mypy_cache/"
            "^__pycache__/"
            "^output/"
            "^data/"
          ];
        };
      };

      gitsigns.enable = true;
      which-key.enable = true;
      lualine.enable = true;

      nvim-cmp = {
        enable = true;
        autoEnableSources = true;
        sources = [
          {name = "nvim_lsp";}
          {name = "path";}
          {name = "buffer";}
          {name = "luasnip";}
        ];
        mapping = {
          "<C-d>" = "cmp.mapping.scroll_docs(-4)";
          "<C-f>" = "cmp.mapping.scroll_docs(4)";
          "<C-Space>" = "cmp.mapping.complete()";
          "<C-e>" = "cmp.mapping.abort()";
          "<CR>" = "cmp.mapping.confirm({ select = true })";
          "<Tab>" = {
            modes = ["i" "s"];
            action = ''
              function(fallback)
                if cmp.visible() then
                  cmp.select_next_item()
                else
                  fallback()
                end
              end
            '';
          };
        };
      };

      luasnip.enable = true;

      lsp = {
        enable = true;
        servers = {
          nil_ls.enable = true; # Nix
          pyright.enable = true; # Python
          gopls.enable = true; # Go
          rust-analyzer.enable = true; # Rust
        };
      };
    };
  };
}
