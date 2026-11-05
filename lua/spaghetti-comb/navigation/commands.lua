-- Enhanced navigation commands
local M = {}

-- Dependencies
local lsp_integration = nil
local history_manager = nil
local debug_utils = nil

-- Module state
local state = {
    config = nil,
    initialized = false,
}

-- Setup the navigation commands
function M.setup(config)
    if state.initialized then return end

    state.config = config

    -- Load dependencies
    lsp_integration = require("spaghetti-comb.navigation.lsp")
    history_manager = require("spaghetti-comb.history.manager")
    debug_utils = require("spaghetti-comb.utils.debug")

    -- Setup dependencies
    lsp_integration.setup(config)
    history_manager.setup(config)
    debug_utils.setup(config.debug or {})

    state.initialized = true
end

-- Enhanced navigation
function M.go_back(count)
    if not state.initialized then return end
    count = count or 1
    local success, entry = history_manager.go_back(count)
    if success and entry then
        M.jump_to_entry(entry)
        debug_utils.debug("Navigated back", { count = count, entry = entry.id })
    end
end

function M.go_forward(count)
    if not state.initialized then return end
    count = count or 1
    local success, entry = history_manager.go_forward(count)
    if success and entry then
        M.jump_to_entry(entry)
        debug_utils.debug("Navigated forward", { count = count, entry = entry.id })
    end
end

function M.jump_to_history_item(index)
    if not state.initialized then return end
    local success, entry = history_manager.navigate_to_index(index)
    if success and entry then
        M.jump_to_entry(entry)
        debug_utils.debug("Jumped to history item", { index = index, entry = entry.id })
    end
end

-- Helper function to jump to a navigation entry
function M.jump_to_entry(entry)
    if not entry or not entry.file_path or not entry.position then return end

    -- Open the file
    vim.cmd("edit " .. vim.fn.fnameescape(entry.file_path))

    -- Jump to the position
    vim.api.nvim_win_set_cursor(0, { entry.position.line, entry.position.column })

    -- Center the cursor
    vim.cmd("normal! zz")
end

-- Quick selection (placeholder for future implementation)
function M.show_history_picker()
    -- TODO: Implement in task 3.4
end

function M.show_branch_picker()
    -- TODO: Implement in task 3.4
end

function M.show_bookmarks_picker()
    -- TODO: Implement in task 3.4
end

-- Bookmark management (placeholder for future implementation)
function M.toggle_bookmark()
    -- TODO: Implement in task 5.1
end

function M.clear_bookmarks()
    -- TODO: Implement in task 5.1
end

function M.list_bookmarks()
    -- TODO: Implement in task 5.1
end

-- LSP-enhanced navigation commands
function M.lsp_go_to_definition()
    if not state.initialized then return end
    lsp_integration.enhanced_go_to_definition()
end

function M.lsp_find_references()
    if not state.initialized then return end
    lsp_integration.enhanced_find_references()
end

function M.lsp_go_to_implementation()
    if not state.initialized then return end
    lsp_integration.enhanced_go_to_implementation()
end

function M.lsp_references_next()
    if not state.initialized then return end
    lsp_integration.navigate_references("next")
end

function M.lsp_references_prev()
    if not state.initialized then return end
    lsp_integration.navigate_references("prev")
end

-- Substrate-powered commands. These don't gate on state.initialized: they only
-- need the vera adapter and the picker, not the LSP hooks commands.setup wires.

-- Semantic search over the codebase; prompt for the query when none is given
---@param query string|nil
function M.seek(query)
    if not query or query == "" then
        vim.ui.input({ prompt = "Seek codebase: " }, function(input)
            if input and input ~= "" then M._run_seek(input) end
        end)
        return
    end
    M._run_seek(query)
end

---@param query string
function M._run_seek(query)
    require("spaghetti-comb.substrate.vera").search(query, { limit = 20 }, function(hits, err)
        if err then
            vim.notify(err, vim.log.levels.WARN)
            return
        end
        require("spaghetti-comb.ui.picker").show_search_hits(
            hits,
            { name = "Seek: " .. query, jump_type = "vera_seek" }
        )
    end)
end

-- Query-by-example: rank implementations related to the code at file_path:line_start-line_end
---@param file_path string
---@param line_start integer
---@param line_end integer
function M.find_related(file_path, line_start, line_end)
    if not file_path or file_path == "" then
        vim.notify("No file in current buffer for query-by-example", vim.log.levels.WARN)
        return
    end

    require("spaghetti-comb.substrate.vera").find_related(
        file_path,
        line_start,
        line_end,
        { limit = 20 },
        function(hits, err)
            if err then
                vim.notify(err, vim.log.levels.WARN)
                return
            end
            require("spaghetti-comb.ui.picker").show_search_hits(
                hits,
                { name = "Related implementations", jump_type = "vera_related" }
            )
        end
    )
end

-- Format one substrate's health line for :SpaghettiCombStatus
---@param tool string
---@param health IndexHealth|nil
---@param err string|nil
---@return string
function M._format_index_health(tool, health, err)
    if err then return err end
    if not health then return string.format("%s: no health info", tool) end

    local parts = {}
    if health.symbol_count then table.insert(parts, health.symbol_count .. " symbols") end
    if health.edge_count then table.insert(parts, health.edge_count .. " edges") end
    if health.indexed_files then table.insert(parts, health.indexed_files .. " files") end
    if health.index_age_seconds then
        table.insert(parts, "index age " .. M._format_duration(health.index_age_seconds))
    end

    local status = health.healthy and "ok" or "unhealthy"
    local detail = #parts > 0 and (" — " .. table.concat(parts, ", ")) or ""
    local message = health.message and health.message ~= "" and ("; " .. health.message) or ""
    return string.format("%s index: %s%s%s", tool, status, detail, message)
end

---@param seconds number
---@return string
function M._format_duration(seconds)
    if seconds < 3600 then return string.format("%dm", math.floor(seconds / 60)) end
    if seconds < 86400 then return string.format("%dh", math.floor(seconds / 3600)) end
    return string.format("%dd", math.floor(seconds / 86400))
end

-- Navigation status plus substrate index health. Health calls are async; the
-- notification goes out once both adapters have answered.
function M.status()
    local status = require("spaghetti-comb.ui.statusline").get_branch_status()
    local lines = {}
    if status then
        table.insert(
            lines,
            string.format(
                "Branch: %s, Depth: %d/%d, State: %s",
                status.branch_id,
                status.depth,
                status.total,
                status.state
            )
        )
    else
        table.insert(lines, "No active navigation")
    end

    local pending = 2
    local results = {}
    local function finish()
        pending = pending - 1
        if pending > 0 then return end
        for _, tool in ipairs({ "codanna", "vera" }) do
            table.insert(lines, results[tool])
        end
        vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO)
    end

    require("spaghetti-comb.substrate.codanna").index_health(function(health, err)
        results.codanna = M._format_index_health("codanna", health, err)
        finish()
    end)
    require("spaghetti-comb.substrate.vera").index_health(function(health, err)
        results.vera = M._format_index_health("vera", health, err)
        finish()
    end)
end

-- History management
function M.clear_history()
    if not state.initialized then return end
    history_manager.clear_all_history()
    debug_utils.info("Cleared all navigation history")
end

function M.clear_project_history()
    if not state.initialized then return end
    history_manager.clear_current_project_history()
    debug_utils.info("Cleared current project navigation history")
end

return M
