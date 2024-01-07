local on_attach = function(client, bufnr)
	local function createOpts(description)
		return {
			buffer = bufnr,
			remap = false,
			desc = description,
		}
	end

	-- Mappings.
	-- See `:help vim.diagnostic.*` for documentation on any of the below functions
	vim.keymap.set("n", "<leader>e", function()
		vim.diagnostic.open_float()
	end, createOpts("Open LSP diagnostics float"))
	vim.keymap.set("n", "[d", function()
		vim.diagnostic.goto_prev()
	end, createOpts("Go to previous LSP diagnostic"))
	vim.keymap.set("n", "]d", function()
		vim.diagnostic.goto_next()
	end, createOpts("Go to next LSP diagnostic"))
	vim.keymap.set("n", "gd", function()
		vim.lsp.buf.definition()
	end, createOpts("Go to definition"))
	vim.keymap.set("n", "gD", function()
		vim.lsp.buf.type_definition()
	end, createOpts("Go to the type definition"))
	vim.keymap.set("n", "gi", function()
		vim.lsp.buf.implementation()
	end, createOpts("Go to implementation"))
	vim.keymap.set("n", "gr", function()
		vim.lsp.buf.references()
	end, createOpts("Go to references"))
	vim.keymap.set("n", "K", function()
		vim.lsp.buf.hover()
	end, createOpts("LSP hover"))
	vim.keymap.set({ "n", "i" }, "<C-s>", function()
		vim.lsp.buf.signature_help()
	end, createOpts("Signature help"))
	vim.keymap.set("n", "<leader>rn", ":IncRename ", createOpts("LSP rename"))
	vim.keymap.set("n", "<leader>cda", function()
		vim.lsp.buf.code_action()
	end, createOpts("LSP code action"))
	vim.keymap.set("n", "<leader>fo", function()
		vim.lsp.buf.format({ timeout_ms = 5000 })
	end, createOpts("LSP format"))

	-- Set autocommands conditional on server_capabilities
	if client.server_capabilities.documentHighlightProvider then
		local group = vim.api.nvim_create_augroup("LSPDocumentHighlight", {})
		vim.api.nvim_create_autocmd({ "CursorHold" }, {
			buffer = bufnr,
			group = group,
			callback = function()
				vim.lsp.buf.document_highlight()
			end,
		})
		vim.api.nvim_create_autocmd({ "CursorMoved" }, {
			buffer = bufnr,
			group = group,
			callback = function()
				vim.lsp.buf.clear_references()
			end,
		})
	end

	if client.server_capabilities.documentFormattingProvider then
		vim.api.nvim_create_autocmd({ "BufWritePre" }, {
			buffer = bufnr,
			callback = function()
				vim.lsp.buf.format({ timeout_ms = 2000 })
			end,
		})
	end
	-- if client.server_capabilities.signatureHelpProvider then
	--     vim.api.nvim_create_autocmd({ "CursorHoldI" }, {
	--         buffer=bufnr,
	--         callback = function()
	--             vim.lsp.buf.signature_help()
	--         end,
	--     })
	-- end
	vim.api.nvim_create_autocmd({ "CursorHold" }, {
		buffer = bufnr,
		callback = function()
			vim.diagnostic.open_float(0, { focusable = false })
		end,
	})
	vim.lsp.handlers["textDocument/publishDiagnostics"] = vim.lsp.with(vim.lsp.diagnostic.on_publish_diagnostics, {
		virtual_text = {
			prefix = "",
		},
		severity_sort = true,
		underline = true,
		signs = true,
	})
end

-- LSP servers

local capabilities = require("cmp_nvim_lsp").default_capabilities()

require("lspconfig").pyright.setup({
	on_attach = function(client, bufnr)
		on_attach(client, bufnr)
	end,
	capabilities = capabilities,
})

require("typescript-tools").setup({
	on_attach = function(client, bufnr)
		client.server_capabilities.documentFormattingProvider = nil
		client.server_capabilities.documentRangeFormattingProvider = nil
		-- local ts_utils = require("nvim-lsp-ts-utils")
		-- ts_utils.setup({})
		-- ts_utils.setup_client(client)

		-- buf_map(bufnr, "n", "gs", ":TSLspOrganize<CR>")
		-- buf_map(bufnr, "n", "gi", ":TSLspRenameFile<CR>")
		-- buf_map(bufnr, "n", "go", ":TSLspImportAll<CR>")

		on_attach(client, bufnr)
	end,
	capabilities = capabilities,
})

require("lspconfig").lua_ls.setup({
	capabilities = capabilities,
	on_attach = on_attach,
	settings = {
		Lua = {
			runtime = {
				-- Tell the language server which version of Lua you're using (most likely LuaJIT in the case of Neovim)
				version = "LuaJIT",
			},
			diagnostics = {
				-- Get the language server to recognize the `vim` global
				globals = { "vim" },
			},
			workspace = {
				-- Make the server aware of Neovim runtime files
				library = vim.api.nvim_get_runtime_file("", true),
				checkThirdParty = true,
			},
			-- Do not send telemetry data containing a randomized but unique identifier
			telemetry = {
				enable = false,
			},
		},
	},
})

require("lspconfig").nil_ls.setup({
	capabilities = capabilities,
	on_attach = on_attach,
	settings = {
		["nil"] = {
			nix = {
				flake = {
					autoEvalInputs = false,
				},
			},
		},
	},
})

local root_patterns = {
	eslint = ".eslintrc.json",
	python = "pyproject.toml",
}

local null_ls_utils = require("null-ls.utils")

local get_root_finder = function(kind)
	local pattern = root_patterns[kind]
	if not pattern then
		error("Unkown kind: " .. kind)
	end

	return function(params)
		return null_ls_utils.root_pattern(pattern)(params.bufname)
	end
end

local null_ls = require("null-ls")
null_ls.setup({
	debug = true,
	sources = {
		-- null_ls.builtins.code_actions.eslint_d,
		null_ls.builtins.diagnostics.eslint_d.with({
			cwd = get_root_finder("eslint"),
		}),
		null_ls.builtins.diagnostics.flake8,
		null_ls.builtins.diagnostics.jsonlint,
		-- null_ls.builtins.diagnostics.mypy,
		null_ls.builtins.formatting.eslint_d.with({
			cwd = get_root_finder("eslint"),
		}),
		null_ls.builtins.formatting.fixjson,
		null_ls.builtins.formatting.autopep8,
		null_ls.builtins.formatting.isort,
		null_ls.builtins.formatting.black,
		null_ls.builtins.formatting.alejandra,
		null_ls.builtins.formatting.stylua,
		null_ls.builtins.formatting.yamlfmt,
	},
	on_attach = on_attach,
})

require("inc_rename").setup()

LaunchWing = function()
	local client_id = vim.lsp.start_client({ cmd = { "wing", "lsp" } })
	vim.lsp.buf_attach_client(0, client_id)
end

vim.cmd([[
	command! -range LaunchWing execute 'lua LaunchWing()'
]])
