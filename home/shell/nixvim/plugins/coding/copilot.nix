{
  config,
  lib,
  pkgs,
  ...
}: {
  programs.nixvim = {
    extraPlugins = with pkgs.vimPlugins; [
      copilot-lua
      copilot-cmp
    ];

    extraConfigLua = ''
      -- Configure copilot
      require("copilot").setup({
        suggestion = { enabled = false },
        panel = { enabled = false },
      })

      -- Configure copilot-cmp
      require("copilot_cmp").setup({
        method = "getCompletionsCycling",
        formatters = {
          label = require("copilot_cmp.format").format_label_text,
          insert_text = require("copilot_cmp.format").format_insert_text,
          preview = require("copilot_cmp.format").deindent,
        },
      })

      -- Add custom highlight for Copilot suggestions
      vim.api.nvim_create_autocmd("ColorScheme", {
        pattern = "*",
        callback = function()
          vim.api.nvim_set_hl(0, "CmpItemKindCopilot", { fg = "#8ec07c" })
        end
      })
    '';
  };
}
