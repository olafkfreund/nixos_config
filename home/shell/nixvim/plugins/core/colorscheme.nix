{
  config,
  lib,
  pkgs,
  ...
}: {
  programs.nixvim = {
    # Setting up gruvbox theme (common in your configuration)
    colorschemes.gruvbox = {
      enable = true;
      settings = {
        contrast_dark = "hard";
        contrast_light = "hard";
        bold = true;
        italic = {
          strings = true;
          emphasis = true;
          comments = true;
          operators = false;
          folds = true;
        };
        strikethrough = true;
        invert_selection = false;
        invert_signs = false;
        invert_tabline = false;
        invert_intend_guides = false;
        inverse = true;
        transparent_mode = false;
      };
    };

    # Configuration for other themes if desired
    extraConfigLua = ''
      -- Set colorscheme with customizations
      vim.opt.background = "dark"

      -- Highlight customizations can be added here
      vim.api.nvim_create_autocmd("ColorScheme", {
        pattern = "*",
        callback = function()
          -- Custom highlight groups
          vim.api.nvim_set_hl(0, "CmpItemKindCopilot", { fg = "#8ec07c" })
          vim.api.nvim_set_hl(0, "CopilotSuggestion", { fg = "#665c54" })
        end,
      })
    '';
  };
}
