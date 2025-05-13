{
  config,
  lib,
  pkgs,
  ...
}: {
  programs.nixvim = {
    plugins = {
      # Auto-completion engine
      nvim-cmp = {
        enable = true;

        snippet.expand = "luasnip";

        mapping = {
          "<C-n>" = "cmp.mapping.select_next_item()";
          "<C-p>" = "cmp.mapping.select_prev_item()";
          "<C-j>" = "cmp.mapping.select_next_item()";
          "<C-k>" = "cmp.mapping.select_prev_item()";
          "<C-d>" = "cmp.mapping.scroll_docs(4)";
          "<C-u>" = "cmp.mapping.scroll_docs(-4)";
          "<C-Space>" = "cmp.mapping.complete()";
          "<C-e>" = "cmp.mapping.abort()";
          "<CR>" = ''
            cmp.mapping.confirm({
              behavior = cmp.ConfirmBehavior.Replace,
              select = false,
            })
          '';
          "<Tab>" = ''
            function(fallback)
              if cmp.visible() then
                cmp.select_next_item()
              else
                fallback()
              end
            end
          '';
          "<S-Tab>" = ''
            function(fallback)
              if cmp.visible() then
                cmp.select_prev_item()
              else
                fallback()
              end
            end
          '';
        };

        sources = [
          {
            name = "copilot";
            priority = 1000;
            group_index = 1;
          }
          {
            name = "nvim_lsp";
            priority = 900;
            group_index = 1;
          }
          {
            name = "luasnip";
            priority = 750;
            group_index = 2;
          }
          {
            name = "buffer";
            priority = 500;
            group_index = 2;
          }
          {
            name = "path";
            priority = 250;
            group_index = 2;
          }
        ];

        formatting = {
          fields = ["abbr" "kind" "menu"];
          format = ''
            function(entry, vim_item)
              local lspkind_icons = {
                Text = "",
                Method = "",
                Function = "",
                Constructor = "",
                Field = "",
                Variable = "",
                Class = "ﴯ",
                Interface = "",
                Module = "",
                Property = "ﰠ",
                Unit = "",
                Value = "",
                Enum = "",
                Keyword = "",
                Snippet = "",
                Color = "",
                File = "",
                Reference = "",
                Folder = "",
                EnumMember = "",
                Constant = "",
                Struct = "",
                Event = "",
                Operator = "",
                TypeParameter = "",
                Copilot = "",
              }

              -- From lspkind.lua in its repo
              local kind = require("lspkind").cmp_format({
                mode = "symbol_text",
                maxwidth = 50,
                ellipsis_char = "...",
                symbol_map = lspkind_icons,
              })(entry, vim_item)

              return kind
            end
          '';
        };
      };

      # Snippet engine
      luasnip = {
        enable = true;
        fromVscode = [{}];
      };

      # Additional completion sources
      cmp-buffer.enable = true;
      cmp-path.enable = true;
      cmp-nvim-lsp.enable = true;
      cmp-nvim-lua.enable = true;
      cmp_luasnip.enable = true;
    };

    extraPlugins = with pkgs.vimPlugins; [
      friendly-snippets # Collection of snippets
    ];
  };
}
