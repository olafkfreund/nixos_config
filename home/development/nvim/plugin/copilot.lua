{
    "zbirenbaum/copilot.lua",
    cmd = "Copilot",
    event = "InsertEnter",
    config = function()
        require("copilot").setup({
            suggestions = { enabled = false },
            panel = { enabled = true },
        })
    end,
}
table.insert(lvim.plugins, {
	"zbirenbaum/copilot-cmp",
	event = "InsertEnter",
	dependencies = { "zbirenbaum/copilot.lua" },
	config = function()
		local ok, cmp = pcall(require, "copilot_cmp")
		if ok then
			cmp.setup({})
		end
	end,
})