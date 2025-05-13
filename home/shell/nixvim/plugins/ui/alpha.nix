{
  config,
  lib,
  pkgs,
  ...
}: {
  programs.nixvim = {
    plugins.alpha = {
      enable = true;
      theme = "dashboard";
      iconsEnabled = true;

      extraConfig = ''
        local dashboard = require("alpha.themes.dashboard")

        -- Set header
        dashboard.section.header.val = {
          "                                                     ",
          "  ███╗   ██╗██╗██╗  ██╗██╗   ██╗██╗███╗   ███╗      ",
          "  ████╗  ██║██║╚██╗██╔╝██║   ██║██║████╗ ████║      ",
          "  ██╔██╗ ██║██║ ╚███╔╝ ██║   ██║██║██╔████╔██║      ",
          "  ██║╚██╗██║██║ ██╔██╗ ╚██╗ ██╔╝██║██║╚██╔╝██║      ",
          "  ██║ ╚████║██║██╔╝ ██╗ ╚████╔╝ ██║██║ ╚═╝ ██║      ",
          "  ╚═╝  ╚═══╝╚═╝╚═╝  ╚═╝  ╚═══╝  ╚═╝╚═╝     ╚═╝      ",
          "                                                     ",
        }

        -- Set menu
        dashboard.section.buttons.val = {
          dashboard.button("e", "  New file", ":ene <BAR> startinsert <CR>"),
          dashboard.button("f", "  Find file", ":Telescope find_files <CR>"),
          dashboard.button("r", "󰄉  Recent files", ":Telescope oldfiles <CR>"),
          dashboard.button("g", "  Find text", ":Telescope live_grep <CR>"),
          dashboard.button("c", "  Config", ":e ~/.config/nixos/home/shell/nixvim/default.nix <CR>"),
          dashboard.button("s", "  Sessions", ":Telescope persisted <CR>"),
          dashboard.button("q", "󰅚  Quit", ":qa<CR>"),
        }

        -- Set footer
        local function getRandomQuote()
          local quotes = {
            {"The best way to predict the future is to create it.", "Abraham Lincoln"},
            {"Life is what happens when you're busy making other plans.", "John Lennon"},
            {"The only way to do great work is to love what you do.", "Steve Jobs"},
            {"In the middle of difficulty lies opportunity.", "Albert Einstein"},
            {"Code is like humor. When you have to explain it, it's bad.", "Cory House"},
            {"First, solve the problem. Then, write the code.", "John Johnson"},
            {"Experience is the name everyone gives to their mistakes.", "Oscar Wilde"},
            {"Any fool can write code that a computer can understand. Good programmers write code that humans can understand.", "Martin Fowler"},
          }

          math.randomseed(os.time())
          local selection = math.random(1, #quotes)
          local quote = quotes[selection][1] .. "  — " .. quotes[selection][2]

          return quote
        end

        dashboard.section.footer.val = {
          " ",
          getRandomQuote(),
        }

        -- Set header, menu, and footer colors
        dashboard.section.header.opts.hl = "AlphaHeader"
        dashboard.section.buttons.opts.hl = "AlphaButtons"
        dashboard.section.footer.opts.hl = "AlphaFooter"

        -- Send config to alpha
        return dashboard
      '';
    };

    extraConfigLua = ''
      -- Alpha highlight groups
      vim.api.nvim_create_autocmd("ColorScheme", {
        pattern = "*",
        callback = function()
          vim.api.nvim_set_hl(0, "AlphaHeader", { fg = "#89b482" })
          vim.api.nvim_set_hl(0, "AlphaButtons", { fg = "#7daea3" })
          vim.api.nvim_set_hl(0, "AlphaFooter", { fg = "#a9b665" })
        end,
      })
    '';
  };
}
