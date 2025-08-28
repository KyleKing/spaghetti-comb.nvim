local M = {}

local SpaghettiComb = {
	config = {},
	state = {
		navigation_stack = {},
		relations_window = nil,
		active_session = nil,
	},
}

local default_config = {
	relations = {
		width = 50,
		height = 20,
		position = "right",
		auto_preview = true,
		show_coupling = true,
	},
	languages = {
		typescript = { enabled = true, coupling_analysis = true },
		javascript = { enabled = true, coupling_analysis = true },
		python = { enabled = true, coupling_analysis = true },
		rust = { enabled = true, coupling_analysis = false },
		go = { enabled = true, coupling_analysis = false },
	},
	keymaps = {
		show_relations = "<leader>sr",
		find_references = "<leader>sf",
		go_definition = "<leader>sd",
		navigate_next = "<leader>sn",
		navigate_prev = "<leader>sp",
		save_session = "<leader>ss",
		load_session = "<leader>sl",
	},
	coupling = {
		enabled = true,
		threshold_high = 0.7,
		threshold_medium = 0.4,
		show_metrics = true,
	},
}

local function merge_config(user_config)
	return vim.tbl_deep_extend("force", default_config, user_config or {})
end

local function setup_commands()
	vim.api.nvim_create_user_command("SpaghettiCombShow", function()
		require("spaghetti-comb.ui.floating").show_relations()
	end, { desc = "Show Relations panel for symbol under cursor" })

	vim.api.nvim_create_user_command("SpaghettiCombReferences", function()
		require("spaghetti-comb.analyzer").find_references()
	end, { desc = "Show where current function is used" })

	vim.api.nvim_create_user_command("SpaghettiCombDefinition", function()
		require("spaghetti-comb.analyzer").go_to_definition()
	end, { desc = "Show where symbol is defined" })

	vim.api.nvim_create_user_command("SpaghettiCombNext", function()
		require("spaghetti-comb.navigation").navigate_next()
	end, { desc = "Navigate forward in exploration stack" })

	vim.api.nvim_create_user_command("SpaghettiCombPrev", function()
		require("spaghetti-comb.navigation").navigate_prev()
	end, { desc = "Navigate backward in exploration stack" })

	vim.api.nvim_create_user_command("SpaghettiCombToggle", function()
		require("spaghetti-comb.ui.floating").toggle_relations()
	end, { desc = "Toggle Relations panel visibility" })

	vim.api.nvim_create_user_command("SpaghettiCombSave", function()
		require("spaghetti-comb.persistence.storage").save_session()
	end, { desc = "Save current exploration session" })

	vim.api.nvim_create_user_command("SpaghettiCombLoad", function()
		require("spaghetti-comb.persistence.storage").load_session()
	end, { desc = "Load saved exploration session" })
end

local function setup_keymaps()
	local keymaps = SpaghettiComb.config.keymaps

	vim.keymap.set("n", keymaps.show_relations, "<cmd>SpaghettiCombShow<cr>", { desc = "Show Relations panel" })
	vim.keymap.set("n", keymaps.find_references, "<cmd>SpaghettiCombReferences<cr>", { desc = "Find references" })
	vim.keymap.set("n", keymaps.go_definition, "<cmd>SpaghettiCombDefinition<cr>", { desc = "Go to definition" })
	vim.keymap.set("n", keymaps.navigate_next, "<cmd>SpaghettiCombNext<cr>", { desc = "Navigate forward in stack" })
	vim.keymap.set("n", keymaps.navigate_prev, "<cmd>SpaghettiCombPrev<cr>", { desc = "Navigate backward in stack" })
	vim.keymap.set("n", keymaps.save_session, "<cmd>SpaghettiCombSave<cr>", { desc = "Save session" })
	vim.keymap.set("n", keymaps.load_session, "<cmd>SpaghettiCombLoad<cr>", { desc = "Load session" })
end

function M.setup(user_config)
	SpaghettiComb.config = merge_config(user_config)

	setup_commands()
	setup_keymaps()

	require("spaghetti-comb.navigation").init(SpaghettiComb.state.navigation_stack)
end

function M.get_config()
	return SpaghettiComb.config
end

function M.get_state()
	return SpaghettiComb.state
end

return M
