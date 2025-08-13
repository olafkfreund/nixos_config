return {
  "robitx/gp.nvim",
  lazy = false,
  config = function()
    require("gp").setup({
      providers = {
        openai = {
          endpoint = "https://api.openai.com/v1/chat/completions",
          secret = os.getenv("OPENAI_API_KEY"),
        },
        copilot = {
          endpoint = "https://api.githubcopilot.com/chat/completions",
          secret = {
            "bash",
            "-c",
            "cat ~/.config/github-copilot/hosts.json | sed -e 's/.*oauth_token...//;s/\".*//'",
          },
        },
        ollama = {
          endpoint = "http://localhost:11434/v1/chat/completions",
        },
        googleai = {
          endpoint = "https://generativelanguage.googleapis.com/v1beta/models/{{model}}:streamGenerateContent?key={{secret}}",
          secret = os.getenv("GOOGLEAI_API_KEY"),
        },
      },
      agents = {
        {
          name = "Codellama",
          chat = true,
          command = true,
          provider = "ollama",
          model = { model = "deepseek-coder-v2" },
          system_prompt = "I am an AI meticulously crafted to provide programming guidance and code assistance. "
            .. "To best serve you as a computer programmer, please provide detailed inquiries and code snippets when necessary, "
            .. "and expect precise, technical responses tailored to your development needs.\n",
        },
        {
          name = "ChatGPT4",
          chat = true,
          command = false,
          -- string with model name or table with model name and parameters
          model = { model = "gpt-4-1106-preview", temperature = 1.1, top_p = 1 },
          -- system prompt (use this to specify the persona/role of the AI)
          system_prompt = "You are a general AI assistant.\n\n"
            .. "The user provided the additional info about how they would like you to respond:\n\n"
            .. "- If you're unsure don't guess and say you don't know instead.\n"
            .. "- Ask question if you need clarification to provide better answer.\n"
            .. "- Think deeply and carefully from first principles step by step.\n"
            .. "- Zoom out first to see the big picture and then zoom in to details.\n"
            .. "- Use Socratic method to improve your thinking and coding skills.\n"
            .. "- Don't elide any code from your output if the answer requires coding.\n"
            .. "- Take a deep breath; You've got this!\n",
        },
        {
          name = "CodeGPT4",
          chat = false,
          command = true,
          -- string with model name or table with model name and parameters
          model = { model = "gpt-4-1106-preview", temperature = 0.8, top_p = 1 },
          -- system prompt (use this to specify the persona/role of the AI)
          system_prompt = "You are an AI working as a code editor.\n\n"
            .. "Please AVOID COMMENTARY OUTSIDE OF THE SNIPPET RESPONSE.\n"
            .. "START AND END YOUR ANSWER WITH:\n\n```",
        },
      },
      hooks = {
        -- example of usig enew as a function specifying type for the new buffer
        CodeReview = function(gp, params)
          local template = "I have the following code from {{filename}}:\n\n"
            .. "```{{filetype}}\n{{selection}}\n```\n\n"
            .. "Please analyze for code smells and suggest improvements."
          local agent = gp.get_chat_agent()
          gp.Prompt(params, gp.Target.enew("markdown"), nil, agent.model, template, agent.system_prompt)
        end,
        -- example of making :%GpChatNew a dedicated command which
        -- opens new chat with the entire current buffer as a context
        BufferChatNew = function(gp, _)
          -- call GpChatNew command in range mode on whole buffer
          vim.api.nvim_command("%" .. gp.config.cmd_prefix .. "ChatNew")
        end,
      },
    })
  end,
  init = function()
    -- Setup keymaps after plugin loads
    vim.api.nvim_create_autocmd("User", {
      pattern = "LazyDone",
      callback = function()
        if pcall(require, "which-key") then
          require("which-key").register({
            ["<C-g>"] = {
              name = "GPT",
              c = { ":<C-u>'<,'>GpChatNew<cr>", "Visual Chat New" },
              p = { ":<C-u>'<,'>GpChatPaste<cr>", "Visual Chat Paste" },
              t = { ":<C-u>'<,'>GpChatToggle<cr>", "Visual Toggle Chat" },
              r = { ":<C-u>'<,'>GpRewrite<cr>", "Visual Rewrite" },
              a = { ":<C-u>'<,'>GpAppend<cr>", "Visual Append (after)" },
              b = { ":<C-u>'<,'>GpPrepend<cr>", "Visual Prepend (before)" },
              i = { ":<C-u>'<,'>GpImplement<cr>", "Implement selection" },
              n = { "<cmd>GpNextAgent<cr>", "Next Agent" },
              s = { "<cmd>GpStop<cr>", "GpStop" },
              x = { ":<C-u>'<,'>GpContext<cr>", "Visual GpContext" },
            },
          }, { mode = "v" })

          require("which-key").register({
            ["<C-g>"] = {
              name = "GPT",
              c = { "<cmd>GpChatNew<cr>", "New Chat" },
              t = { "<cmd>GpChatToggle<cr>", "Toggle Chat" },
              f = { "<cmd>GpChatFinder<cr>", "Chat Finder" },
              r = { "<cmd>GpRewrite<cr>", "Inline Rewrite" },
              a = { "<cmd>GpAppend<cr>", "Append (after)" },
              b = { "<cmd>GpPrepend<cr>", "Prepend (before)" },
              n = { "<cmd>GpNextAgent<cr>", "Next Agent" },
              s = { "<cmd>GpStop<cr>", "GpStop" },
              x = { "<cmd>GpContext<cr>", "Toggle GpContext" },
            },
          }, { mode = "n" })
        end
      end,
    })
  end,
}
