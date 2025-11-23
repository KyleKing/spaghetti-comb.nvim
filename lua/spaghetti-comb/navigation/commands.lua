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
