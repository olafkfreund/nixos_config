{
  config,
  lib,
  pkgs,
  ...
}: {
  config = {
    programs.nixvim = {
      plugins = {
        which-key = {
          enable = true;
          
          registrations = {
            "<leader>f" = "File operations";
            "<leader>b" = "Buffer operations";
            "<leader>s" = "Search operations";
            "<leader>g" = "Git operations";
            "<leader>l" = "LSP operations";
            "<leader>w" = "Window operations";
            "<leader>t" = "Terminal operations";
            "<leader>h" = "Help";
            "<leader>c" = "Code actions";
          };
          
          setup = {
            plugins = {
              marks = true;
              registers = true;
              spelling = {
                enabled = true;
                suggestions = 20;
              };
              presets = {
                operators = true;
                motions = true;
                text_objects = true;
                windows = true;
                nav = true;
                z = true;
                g = true;
              };
            };
            
            window = {
              border = "rounded";
              position = "bottom";
              margin = {
                top = 1;
                right = 0;
                bottom = 1;
                left = 0;
              };
              padding = {
                top = 1;
                right = 2;
                bottom = 1;
                left = 2;
              };
            };
            
            layout = {
              height = {
                min = 4;
                max = 25;
              };
              width = {
                min = 20;
                max = 50;
              };
              spacing = 3;
              align = "center";
            };
            
            ignore_missing = true;
            hidden = ["<silent>" "<cmd>" "<Cmd>" "<CR>" "^:" "^ " "^call " "^lua "];
            show_help = true;
            triggers = "auto";
            triggers_nowait = [];
            disable = {
              buftypes = [];
              filetypes = ["TelescopePrompt"];
            };
          };
        };
      };
    };
  };
}
