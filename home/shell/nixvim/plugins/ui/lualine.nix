{
  config,
  lib,
  pkgs,
  ...
}: {
  programs.nixvim = {
    plugins.lualine = {
      enable = true;

      globalstatus = true;

      componentSeparators = {
        left = "";
        right = "";
      };

      sectionSeparators = {
        left = "";
        right = "";
      };

      theme = "gruvbox";

      sections = {
        lualine_a = [
          {
            name = "mode";
            extraConfig = {
              padding = {
                left = 1;
                right = 1;
              };
            };
          }
        ];

        lualine_b = [
          {
            name = "branch";
            icon = "";
          }
          {
            name = "diff";
            symbolsNegative = " ";
            symbolsPositive = " ";
            symbolsPlaceholder = " ";
            extraConfig = {
              diff_color = {
                added = {fg = "#98be65";};
                modified = {fg = "#51afef";};
                removed = {fg = "#ec5f67";};
              };
            };
          }
        ];

        lualine_c = [
          {
            name = "filename";
            extraConfig = {
              file_status = true;
              path = 1; # Relative path
              shorting_target = 40;
              symbols = {
                modified = "  ";
                readonly = " ";
                unnamed = "[No Name]";
              };
            };
          }
          {
            name = "diagnostics";
            extraConfig = {
              sources = ["nvim_lsp"];
              symbols = {
                error = " ";
                warn = " ";
                info = " ";
                hint = " ";
              };
            };
          }
        ];

        lualine_x = [
          {
            name = "filetype";
            extraConfig = {
              colored = true;
              icon_only = false;
            };
          }
          {
            name = "encoding";
          }
          {
            name = "fileformat";
            extraConfig = {
              symbols = {
                unix = "LF";
                dos = "CRLF";
                mac = "CR";
              };
            };
          }
        ];

        lualine_y = [
          {
            name = "progress";
            extraConfig = {
              padding = {
                left = 1;
                right = 1;
              };
            };
          }
        ];

        lualine_z = [
          {
            name = "location";
            extraConfig = {
              padding = {
                left = 1;
                right = 1;
              };
            };
          }
        ];
      };

      inactiveSections = {
        lualine_a = [];
        lualine_b = [];
        lualine_c = [
          {
            name = "filename";
            extraConfig = {
              path = 1; # Relative path
            };
          }
        ];
        lualine_x = ["location"];
        lualine_y = [];
        lualine_z = [];
      };

      tabline = {};

      extensions = [
        "neo-tree"
        "lazy"
        "trouble"
        "quickfix"
      ];
    };
  };
}
