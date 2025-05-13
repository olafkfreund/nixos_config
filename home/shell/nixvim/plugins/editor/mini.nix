{
  config,
  lib,
  pkgs,
  ...
}: {
  programs.nixvim = {
    extraPlugins = with pkgs.vimPlugins; [
      mini-nvim
    ];

    extraConfigLua = ''
      -- Configure mini.pairs for auto pairing
      require('mini.pairs').setup({
        -- Which characters to use as parts of pairs
        pairs = {
          ['('] = ')',
          ['['] = ']',
          ['{'] = '}',
          ['"'] = '"',
          ["'"] = "'",
          ['`'] = '`',
        },
        -- Characters for which pairs should not be used
        disable_filetype = { 'TelescopePrompt' },
      })

      -- Configure mini.surround for surrounding text objects
      require('mini.surround').setup({
        mappings = {
          add = 'sa', -- Add surroundings
          delete = 'sd', -- Delete surroundings
          find = 'sf', -- Find surroundings
          find_left = 'sF', -- Find surroundings (to the left)
          highlight = 'sh', -- Highlight surroundings
          replace = 'sr', -- Replace surroundings
          update_n_lines = 'sn', -- Update n lines
        },
      })

      -- Configure mini.ai for improved text objects
      require('mini.ai').setup({
        n_lines = 500,
        custom_textobjects = {
          o = require('mini.ai').gen_spec.treesitter({
            a = { "@block.outer", "@conditional.outer", "@loop.outer" },
            i = { "@block.inner", "@conditional.inner", "@loop.inner" },
          }),
          f = require('mini.ai').gen_spec.treesitter({
            a = "@function.outer",
            i = "@function.inner",
          }),
          c = require('mini.ai').gen_spec.treesitter({
            a = "@class.outer",
            i = "@class.inner",
          }),
        },
      })

      -- Configure mini.comment for improved commenting
      require('mini.comment').setup({
        options = {
          custom_commentstring = function()
            return require('ts_context_commentstring.internal').calculate_commentstring() or vim.bo.commentstring
          end,
        },
      })

      -- Configure mini.indentscope for indentation guides
      require('mini.indentscope').setup({
        symbol = "│",
        options = { try_as_border = true },
        draw = {
          animation = require('mini.indentscope').gen_animation.none()
        }
      })

      -- Disable indentscope for specified filetypes
      vim.api.nvim_create_autocmd("FileType", {
        pattern = {
          "help", "alpha", "dashboard", "neo-tree", "Trouble", "trouble", "lazy",
          "mason", "notify", "toggleterm", "lazyterm"
        },
        callback = function()
          vim.b.miniindentscope_disable = true
        end,
      })
    '';
  };
}
