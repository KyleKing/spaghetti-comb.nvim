-- Spaghetti Comb - Neovim Plugin for Code Exploration
-- Prevent loading if already loaded or if Neovim version is too old
if vim.g.loaded_spaghetti_comb or vim.fn.has("nvim-0.8") ~= 1 then return end
vim.g.loaded_spaghetti_comb = 1

-- Task 11: User commands and keybindings

-- UI Commands
vim.api.nvim_create_user_command("SpaghettiCombBreadcrumbs", function()
    require("spaghetti-comb.ui.breadcrumbs").toggle()
end, { desc = "Toggle breadcrumb trail view" })

vim.api.nvim_create_user_command("SpaghettiCombTree", function()
    require("spaghetti-comb.ui.floating_tree").toggle()
end, { desc = "Toggle navigation tree view with preview" })

vim.api.nvim_create_user_command("SpaghettiCombBookmarks", function()
    require("spaghetti-comb.ui.picker").show_bookmark_mode()
end, { desc = "Show bookmark picker" })

vim.api.nvim_create_user_command("SpaghettiCombHistory", function()
    require("spaghetti-comb.ui.picker").show_navigation_mode()
end, { desc = "Show navigation history picker" })

-- Bookmark Commands
vim.api.nvim_create_user_command("SpaghettiCombBookmarkToggle", function()
    local bookmarks = require("spaghetti-comb.history.bookmarks")
    local pos = vim.api.nvim_win_get_cursor(0)
    local location = {
        file_path = vim.api.nvim_buf_get_name(0),
        position = { line = pos[1], column = pos[2] + 1 },
    }
    local success, action = bookmarks.toggle_bookmark(location)
    if success then vim.notify("Bookmark " .. action, vim.log.levels.INFO) end
end, { desc = "Toggle bookmark at current location" })

vim.api.nvim_create_user_command("SpaghettiCombBookmarkClear", function(opts)
    local bookmarks = require("spaghetti-comb.history.bookmarks")
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
    local history_manager = require("spaghetti-comb.history.manager")
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
    local debug = require("spaghetti-comb.utils.debug")
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
    local debug = require("spaghetti-comb.utils.debug")
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
    local statusline = require("spaghetti-comb.ui.statusline")
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
        local ok, result = pcall(function() return vim.json.decode(opts.args) end)
        if ok then config = result end
    end
    require("spaghetti-comb").setup(config)
    vim.notify("Spaghetti Comb initialized", vim.log.levels.INFO)
end, {
    nargs = "?",
    desc = "Setup Spaghetti Comb",
})

-- Task 12: Persistence commands

-- Save current project history to disk
vim.api.nvim_create_user_command("SpaghettiCombSaveHistory", function()
    local history_manager = require("spaghetti-comb.history.manager")
    local success, msg = history_manager.save_current_project_history()
    local level = success and vim.log.levels.INFO or vim.log.levels.WARN
    vim.notify(msg or "Unknown error", level)
end, { desc = "Save navigation history for current project" })

-- Save all project histories
vim.api.nvim_create_user_command("SpaghettiCombSaveAllHistory", function()
    local history_manager = require("spaghetti-comb.history.manager")
    local success, msg = history_manager.save_all_histories()
    local level = success and vim.log.levels.INFO or vim.log.levels.WARN
    vim.notify(msg or "Unknown error", level)
end, { desc = "Save navigation history for all projects" })

-- Load project history from disk
vim.api.nvim_create_user_command("SpaghettiCombLoadHistory", function()
    local history_manager = require("spaghetti-comb.history.manager")
    local project_utils = require("spaghetti-comb.utils.project")

    local current_file = vim.api.nvim_buf_get_name(0)
    local project_root = project_utils.detect_project_root(current_file)

    if not project_root then
        vim.notify("Could not detect project root", vim.log.levels.WARN)
        return
    end

    local success, msg = history_manager.load_project_history(project_root)
    local level = success and vim.log.levels.INFO or vim.log.levels.WARN
    vim.notify(msg or "Unknown error", level)
end, { desc = "Load navigation history for current project" })

-- Save current project bookmarks
vim.api.nvim_create_user_command("SpaghettiCombSaveBookmarks", function()
    local bookmarks = require("spaghetti-comb.history.bookmarks")
    local success, msg = bookmarks.save_current_project_bookmarks()
    local level = success and vim.log.levels.INFO or vim.log.levels.WARN
    vim.notify(msg or "Unknown error", level)
end, { desc = "Save bookmarks for current project" })

-- Save all project bookmarks
vim.api.nvim_create_user_command("SpaghettiCombSaveAllBookmarks", function()
    local bookmarks = require("spaghetti-comb.history.bookmarks")
    local success, msg = bookmarks.save_all_bookmarks()
    local level = success and vim.log.levels.INFO or vim.log.levels.WARN
    vim.notify(msg or "Unknown error", level)
end, { desc = "Save bookmarks for all projects" })

-- Load project bookmarks from disk
vim.api.nvim_create_user_command("SpaghettiCombLoadBookmarks", function()
    local bookmarks = require("spaghetti-comb.history.bookmarks")
    local project_utils = require("spaghetti-comb.utils.project")

    local current_file = vim.api.nvim_buf_get_name(0)
    local project_root = project_utils.detect_project_root(current_file)

    if not project_root then
        vim.notify("Could not detect project root", vim.log.levels.WARN)
        return
    end

    local success, msg = bookmarks.load_project_bookmarks(project_root)
    local level = success and vim.log.levels.INFO or vim.log.levels.WARN
    vim.notify(msg or "Unknown error", level)
end, { desc = "Load bookmarks for current project" })

-- Clean up old persistence files
vim.api.nvim_create_user_command("SpaghettiCombCleanupPersistence", function(opts)
    local storage = require("spaghetti-comb.history.storage")
    local max_age_days = opts.args and tonumber(opts.args) or 90

    local success, msg = storage.cleanup_persistence(max_age_days)
    local level = success and vim.log.levels.INFO or vim.log.levels.WARN
    vim.notify(msg or "Unknown error", level)
end, {
    nargs = "?",
    desc = "Clean up old persistence files (default: 90 days)",
})

-- Show storage statistics
vim.api.nvim_create_user_command("SpaghettiCombStorageStats", function()
    local storage = require("spaghetti-comb.history.storage")
    local stats = storage.get_storage_stats()

    local msg = string.format(
        "Storage: %s\nHistory files: %d\nBookmark files: %d\nTotal size: %d bytes",
        stats.storage_dir,
        stats.history_count,
        stats.bookmark_count,
        stats.total_size
    )

    vim.notify(msg, vim.log.levels.INFO)
end, { desc = "Show persistence storage statistics" })

-- List saved projects
vim.api.nvim_create_user_command("SpaghettiCombListProjects", function()
    local storage = require("spaghetti-comb.history.storage")
    local projects = storage.list_saved_projects()

    if #projects == 0 then
        vim.notify("No saved projects found", vim.log.levels.INFO)
        return
    end

    local lines = { "Saved projects:" }
    for _, project in ipairs(projects) do
        local date = os.date("%Y-%m-%d %H:%M:%S", project.modified)
        table.insert(lines, string.format("  %s (%s, %d bytes, modified: %s)",
            project.hash, project.type, project.size, date))
    end

    vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO)
end, { desc = "List all saved projects" })

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
