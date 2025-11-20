-- Spaghetti Comb v2 - Neovim Plugin for Code Exploration
-- Prevent loading if already loaded or if Neovim version is too old
if vim.g.loaded_spaghetti_comb_v2 or vim.fn.has("nvim-0.8") ~= 1 then return end
vim.g.loaded_spaghetti_comb_v2 = 1

-- Task 11: User commands and keybindings

-- UI Commands
vim.api.nvim_create_user_command("SpaghettiCombBreadcrumbs", function()
    require("spaghetti-comb-v2.ui.breadcrumbs").toggle()
end, { desc = "Toggle breadcrumb trail view" })

vim.api.nvim_create_user_command("SpaghettiCombTree", function()
    require("spaghetti-comb-v2.ui.floating_tree").toggle()
end, { desc = "Toggle navigation tree view with preview" })

vim.api.nvim_create_user_command("SpaghettiCombBookmarks", function()
    require("spaghetti-comb-v2.ui.picker").show_bookmark_mode()
end, { desc = "Show bookmark picker" })

vim.api.nvim_create_user_command("SpaghettiCombHistory", function()
    require("spaghetti-comb-v2.ui.picker").show_navigation_mode()
end, { desc = "Show navigation history picker" })

-- Bookmark Commands
vim.api.nvim_create_user_command("SpaghettiCombBookmarkToggle", function()
    local bookmarks = require("spaghetti-comb-v2.history.bookmarks")
    local pos = vim.api.nvim_win_get_cursor(0)
    local location = {
        file_path = vim.api.nvim_buf_get_name(0),
        position = { line = pos[1], column = pos[2] + 1 },
    }
    local success, action = bookmarks.toggle_bookmark(location)
    if success then vim.notify("Bookmark " .. action, vim.log.levels.INFO) end
end, { desc = "Toggle bookmark at current location" })

vim.api.nvim_create_user_command("SpaghettiCombBookmarkClear", function(opts)
    local bookmarks = require("spaghetti-comb-v2.history.bookmarks")
    local global = opts.args == "global"
    bookmarks.clear_all_bookmarks(global)
    vim.notify("Bookmarks cleared", vim.log.levels.INFO)
end, {
    nargs = "?",
    complete = function() return { "global" } end,
    desc = "Clear bookmarks (optional: global)",
})

-- History Management Commands
vim.api.nvim_create_user_command("SpaghettiCombHistoryClear", function(opts)
    local history_manager = require("spaghetti-comb-v2.history.manager")
    local project = opts.args ~= "all"
    -- Implementation would clear history
    vim.notify("History clearing not yet fully implemented", vim.log.levels.WARN)
end, {
    nargs = "?",
    complete = function() return { "all" } end,
    desc = "Clear navigation history (optional: all)",
})

-- Debug Commands
vim.api.nvim_create_user_command("SpaghettiCombDebug", function(opts)
    local debug = require("spaghetti-comb-v2.utils.debug")
    if opts.args == "history" then
        debug.dump_history()
    elseif opts.args == "bookmarks" then
        debug.dump_bookmarks()
    elseif opts.args == "config" then
        debug.dump_config()
    else
        debug.dump_all_state()
    end
end, {
    nargs = "?",
    complete = function() return { "history", "bookmarks", "config" } end,
    desc = "Dump debug information",
})

vim.api.nvim_create_user_command("SpaghettiCombLogLevel", function(opts)
    local debug = require("spaghetti-comb-v2.utils.debug")
    local level = opts.args
    if level and level ~= "" then
        debug.set_log_level(level)
        vim.notify("Log level set to: " .. level, vim.log.levels.INFO)
    else
        vim.notify("Usage: :SpaghettiCombLogLevel <debug|info|warn|error>", vim.log.levels.INFO)
    end
end, {
    nargs = 1,
    complete = function() return { "debug", "info", "warn", "error" } end,
    desc = "Set log level",
})

-- Statusline Integration
vim.api.nvim_create_user_command("SpaghettiCombStatus", function()
    local statusline = require("spaghetti-comb-v2.ui.statusline")
    local status = statusline.get_branch_status()
    if status then
        vim.notify(string.format("Branch: %s, Depth: %d/%d, State: %s", status.branch_id, status.depth, status.total, status.state), vim.log.levels.INFO)
    else
        vim.notify("No active navigation", vim.log.levels.INFO)
    end
end, { desc = "Show current navigation status" })

-- Main setup command (optional manual setup)
vim.api.nvim_create_user_command("SpaghettiCombSetup", function(opts)
    -- Parse opts.args as lua table if provided
    local config = {}
    if opts.args and opts.args ~= "" then
        local ok, result = pcall(loadstring("return " .. opts.args))
        if ok then config = result end
    end
    require("spaghetti-comb-v2").setup(config)
    vim.notify("Spaghetti Comb v2 initialized", vim.log.levels.INFO)
end, {
    nargs = "?",
    desc = "Setup Spaghetti Comb v2",
})

-- Optional: Default keymappings (users can override these)
-- Uncomment to enable default keymaps
--[[
vim.keymap.set("n", "<leader>sb", "<cmd>SpaghettiCombBreadcrumbs<cr>", { desc = "Toggle breadcrumbs" })
vim.keymap.set("n", "<leader>st", "<cmd>SpaghettiCombTree<cr>", { desc = "Toggle navigation tree" })
vim.keymap.set("n", "<leader>sm", "<cmd>SpaghettiCombBookmarks<cr>", { desc = "Show bookmarks" })
vim.keymap.set("n", "<leader>sh", "<cmd>SpaghettiCombHistory<cr>", { desc = "Show history" })
vim.keymap.set("n", "<leader>sB", "<cmd>SpaghettiCombBookmarkToggle<cr>", { desc = "Toggle bookmark" })
vim.keymap.set("n", "<leader>ss", "<cmd>SpaghettiCombStatus<cr>", { desc = "Show status" })
--]]
