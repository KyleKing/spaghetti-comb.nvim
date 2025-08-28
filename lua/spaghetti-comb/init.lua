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
        call_hierarchy_incoming = "<leader>sci",
        call_hierarchy_outgoing = "<leader>sco",
        show_navigation_history = "<leader>sh",
        bookmark_current = "<leader>sb",
    },
    coupling = {
        enabled = true,
        threshold_high = 0.7,
        threshold_medium = 0.4,
        show_metrics = true,
    },
}

local function merge_config(user_config) return vim.tbl_deep_extend("force", default_config, user_config or {}) end

local function setup_commands()
    vim.api.nvim_create_user_command(
        "SpaghettiCombShow",
        function() require("spaghetti-comb.ui.floating").show_relations() end,
        { desc = "Show Relations panel for symbol under cursor" }
    )

    vim.api.nvim_create_user_command(
        "SpaghettiCombReferences",
        function() require("spaghetti-comb.analyzer").find_references() end,
        { desc = "Show where current function is used" }
    )

    vim.api.nvim_create_user_command(
        "SpaghettiCombDefinition",
        function() require("spaghetti-comb.analyzer").go_to_definition() end,
        { desc = "Show where symbol is defined" }
    )

    vim.api.nvim_create_user_command(
        "SpaghettiCombNext",
        function() require("spaghetti-comb.navigation").navigate_next() end,
        { desc = "Navigate forward in exploration stack" }
    )

    vim.api.nvim_create_user_command(
        "SpaghettiCombPrev",
        function() require("spaghetti-comb.navigation").navigate_prev() end,
        { desc = "Navigate backward in exploration stack" }
    )

    vim.api.nvim_create_user_command(
        "SpaghettiCombToggle",
        function() require("spaghetti-comb.ui.floating").toggle_relations() end,
        { desc = "Toggle Relations panel visibility" }
    )

    vim.api.nvim_create_user_command(
        "SpaghettiCombSave",
        function(opts) require("spaghetti-comb.persistence.storage").save_session(opts.args ~= "" and opts.args or nil) end,
        { desc = "Save current exploration session", nargs = "?" }
    )

    vim.api.nvim_create_user_command(
        "SpaghettiCombLoad",
        function(opts) require("spaghetti-comb.persistence.storage").load_session(opts.args ~= "" and opts.args or nil) end,
        { desc = "Load saved exploration session", nargs = "?" }
    )

    vim.api.nvim_create_user_command("SpaghettiCombListSessions", function()
        local sessions = require("spaghetti-comb.persistence.storage").list_sessions()
        if #sessions == 0 then
            require("spaghetti-comb.utils").info("No saved sessions found")
        else
            local lines = { "Available sessions:" }
            for _, session in ipairs(sessions) do
                table.insert(
                    lines,
                    string.format("  %s (modified: %s)", session.name, os.date("%Y-%m-%d %H:%M", session.mtime))
                )
            end
            vim.notify(table.concat(lines, "\n"))
        end
    end, { desc = "List all saved exploration sessions" })

    vim.api.nvim_create_user_command(
        "SpaghettiCombCallHierarchyIncoming",
        function() require("spaghetti-comb.analyzer").get_call_hierarchy_incoming() end,
        { desc = "Show incoming calls (who calls this function)" }
    )

    vim.api.nvim_create_user_command(
        "SpaghettiCombCallHierarchyOutgoing",
        function() require("spaghetti-comb.analyzer").get_call_hierarchy_outgoing() end,
        { desc = "Show outgoing calls (what this function calls)" }
    )

    vim.api.nvim_create_user_command("SpaghettiCombNavigationHistory", function()
        local summary = require("spaghetti-comb.navigation").get_navigation_summary()
        if #summary.entries == 0 then
            require("spaghetti-comb.utils").info("Navigation stack is empty")
        else
            local lines = { string.format("Navigation History (%d/%d):", summary.current_index, summary.total) }
            for _, entry in ipairs(summary.entries) do
                local marker = entry.is_current and ">> " or "   "
                local bookmark = entry.bookmarked and "★ " or ""
                table.insert(
                    lines,
                    string.format("%s%s%s:%d %s", marker, bookmark, entry.relative_path, entry.line, entry.symbol)
                )
            end
            vim.notify(table.concat(lines, "\n"))
        end
    end, { desc = "Show navigation history" })

    vim.api.nvim_create_user_command("SpaghettiCombBookmarkCurrent", function()
        require("spaghetti-comb.navigation").update_current_entry({ bookmarked = true })
        require("spaghetti-comb.utils").info("Current navigation entry bookmarked")
    end, { desc = "Bookmark current navigation entry" })

    vim.api.nvim_create_user_command(
        "SpaghettiCombAnalyze",
        function() require("spaghetti-comb.analyzer").analyze_current_symbol() end,
        { desc = "Analyze current symbol (show all relations)" }
    )
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
    vim.keymap.set(
        "n",
        keymaps.call_hierarchy_incoming,
        "<cmd>SpaghettiCombCallHierarchyIncoming<cr>",
        { desc = "Show incoming calls" }
    )
    vim.keymap.set(
        "n",
        keymaps.call_hierarchy_outgoing,
        "<cmd>SpaghettiCombCallHierarchyOutgoing<cr>",
        { desc = "Show outgoing calls" }
    )
    vim.keymap.set(
        "n",
        keymaps.show_navigation_history,
        "<cmd>SpaghettiCombNavigationHistory<cr>",
        { desc = "Show navigation history" }
    )
    vim.keymap.set(
        "n",
        keymaps.bookmark_current,
        "<cmd>SpaghettiCombBookmarkCurrent<cr>",
        { desc = "Bookmark current" }
    )
end

function M.setup(user_config)
    SpaghettiComb.config = merge_config(user_config)

    setup_commands()
    setup_keymaps()

    require("spaghetti-comb.navigation").init(SpaghettiComb.state.navigation_stack)
end

function M.get_config() return SpaghettiComb.config end

function M.get_state() return SpaghettiComb.state end

return M
