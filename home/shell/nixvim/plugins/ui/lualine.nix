{
  config,
  lib,
  pkgs,
  ...
}: {
  config = {
    programs.nixvim = {
      plugins.lualine = {
        enable = true;
        theme = "gruvbox";
        componentSeparators = {
          left = "";
          right = "";
        };
        sectionSeparators = {
          left = "";
          right = "";
        };
        globalstatus = true;
        alwaysDivideMiddle = true;

        sections = {
          lualine_a = [
            {
              name = "mode";
            }
          ];

          lualine_b = [
            {
              name = "branch";
            }
            {
              name = "diff";
              symbols = {
                added = " ";
                modified = " ";
                removed = " ";
              };
            }
          ];

          lualine_c = [
            {
              name = "filename";
              filetype_names = {
                TelescopePrompt = "Telescope";
                dashboard = "Dashboard";
                packer = "Packer";
                fzf = "FZF";
                alpha = "Alpha";
              };
              symbols = {
                modified = "  ";
                readonly = " ";
                unnamed = "[No Name]";
              };
            }
            {
              name = "diagnostics";
              symbols = {
                error = " ";
                warn = " ";
                info = " ";
                hint = " ";
              };
            }
          ];

          lualine_x = [
            {
              name = "encoding";
            }
            {
              name = "fileformat";
            }
            {
              name = "filetype";
            }
          ];

          lualine_y = [
            {
              name = "progress";
            }
          ];

          lualine_z = [
            {
              name = "location";
            }
          ];
        };

        inactiveSections = {
          lualine_a = [];
          lualine_b = [];
          lualine_c = [
            {
              name = "filename";
            }
          ];
          lualine_x = [
            {
              name = "location";
            }
          ];
          lualine_y = [];
          lualine_z = [];
        };

        extensions = [
          "quickfix"
          "fugitive"
          "fzf"
          "trouble"
        ];
      };
    };
  };
}
