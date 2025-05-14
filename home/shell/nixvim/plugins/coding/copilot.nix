{
  pkgs,
  lib,
  ...
}: {
  programs.nixvim = {
    plugins = {
      copilot-lua = {
        enable = true;
        suggestion = {
          enabled = true;
          autoTrigger = true;
          keymap = {
            accept = "<M-l>";
            acceptWord = "<M-;>";
            acceptLine = "<M-]>";
            next = "<M-]>";
            prev = "<M-[>";
            dismiss = "<C-]>";
          };
        };
        panel = {
          enabled = true;
          autoRefresh = true;
          keymap = {
            jumpPrev = "[[";
            jumpNext = "]]";
            accept = "<CR>";
            refresh = "gr";
            open = "<M-CR>";
          };
        };
      };

      copilot-cmp = {
        enable = true;
        event = ["InsertEnter" "LspAttach"];
      };
    };

    extraConfigLua = ''
      -- Copilot status in lualine
      local function copilot_status()
        local client = vim.lsp.get_active_clients({ name = "copilot" })[1]
        if client == nil then
          return ""
        end
        if client.attached then
          return " "
        end
        return ""
      end

      -- Add copilot status to lualine
      require("lualine").setup({
        sections = {
          lualine_x = {
            copilot_status,
            "encoding",
            "fileformat",
            "filetype"
          }
        }
      })
    '';
  };
}
