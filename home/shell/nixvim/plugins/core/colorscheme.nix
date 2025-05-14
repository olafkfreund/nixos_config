{
  pkgs,
  lib,
  ...
}: {
  programs.nixvim = {
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

    highlight = {
      Comment.fg = "#928374";
      Comment.italic = true;
      CmpItemKindCopilot.fg = "#8ec07c";
      CopilotSuggestion.fg = "#665c54";
    };
  };
}
