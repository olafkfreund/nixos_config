{
  pkgs,
  lib,
  ...
}: {
  programs.nixvim = {
    plugins = {
      nvim-cmp = {
        enable = true;
        autoEnableSources = true;
        sources = [
          {name = "nvim_lsp";}
          {name = "luasnip";}
          {name = "path";}
          {name = "buffer";}
          {name = "copilot";}
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
                elseif luasnip.expand_or_jumpable() then
                  luasnip.expand_or_jump()
                else
                  fallback()
                end
              end
            '';
          };
          "<S-Tab>" = {
            modes = ["i" "s"];
            action = ''
              function(fallback)
                if cmp.visible() then
                  cmp.select_prev_item()
                elseif luasnip.jumpable(-1) then
                  luasnip.jump(-1)
                else
                  fallback()
                end
              end
            '';
          };
        };

        snippet.expand = "luasnip";

        formatting = {
          format = ''
            function(entry, vim_item)
              -- Set icons for completion items
              local kind_icons = {
                Text = "",
                Method = "",
                Function = "",
                Constructor = "",
                Field = "",
                Variable = "",
                Class = "",
                Interface = "",
                Module = "",
                Property = "",
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

              -- Set menu text based on source
              local menu_texts = {
                nvim_lsp = "[LSP]",
                luasnip = "[Snippet]",
                buffer = "[Buffer]",
                path = "[Path]",
                copilot = "[Copilot]",
              }

              -- Add icons and source menu text
              vim_item.kind = string.format('%s %s', kind_icons[vim_item.kind], vim_item.kind)
              vim_item.menu = menu_texts[entry.source.name]

              return vim_item
            end
          '';
        };

        window = {
          completion = {
            border = "rounded";
            winhighlight = "Normal:CmpPmenu,FloatBorder:CmpPmenuBorder,CursorLine:PmenuSel,Search:None";
          };
          documentation = {
            border = "rounded";
            winhighlight = "Normal:CmpDoc";
          };
        };
      };

      luasnip = {
        enable = true;
        fromVscode = true;

        extraConfig = {
          enable_autosnippets = true;
          store_selection_keys = "<Tab>";
        };
      };
    };
  };
}
