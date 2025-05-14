{
  pkgs,
  lib,
  ...
}: {
  programs.nixvim = {
    plugins = {
      nvim-autopairs = {
        enable = true;
        checkTs = true;

        fastwrap.enable = true;

        disabledFiletypes = ["TelescopePrompt" "vim"];

        enableAfterQuote = ["html" "xml"];
        enableCheckBracketLine = true;
        enableMoveright = true;
        disableInMacro = false;
        disableInVisualblock = false;
        ignoreNextChar = "[=[[%w%%%'%[%\"%.%`%$]]=]";
      };
    };

    extraConfigLua = ''
      -- Set up nvim-autopairs with nvim-cmp
      local status_ok, npairs = pcall(require, "nvim-autopairs")
      if status_ok then
        local cmp_autopairs = require("nvim-autopairs.completion.cmp")
        local cmp_status_ok, cmp = pcall(require, "cmp")
        if cmp_status_ok then
          cmp.event:on("confirm_done", cmp_autopairs.on_confirm_done())
        end
      end
    '';
  };
}
