-- Branch status display in statusline
local M = {}

-- Module state
local state = {
    config = nil,
    initialized = false,
}

-- Setup statusline system
function M.setup(config)
    state.config = config or {}
    state.initialized = true
end

-- Task 10.1: Branch status display

-- Get current branch status
function M.get_branch_status()
    if not state.initialized then return nil end

    local history_manager = require("spaghetti-comb-v2.history.manager")
    local trail = history_manager.get_current_trail()

    if not trail or #trail.entries == 0 then return nil end

    local exploration_state = history_manager.determine_exploration_state()
    local current_branch = trail.branches.current or "main"
    local depth = trail.current_index or 0
    local total = #trail.entries

    return {
        branch_id = current_branch,
        depth = depth,
        total = total,
        state = exploration_state,
        project = trail.project_root,
    }
end

-- Format active exploration status
function M.format_active_exploration(branch_id, depth, total)
    -- Minimal format: branch_id:depth/total
    local short_id = branch_id:sub(1, 8) -- First 8 chars of branch ID
    return string.format("🔍 %s:%d/%d", short_id, depth or 0, total or 0)
end

-- Format idle indicator
function M.format_idle_indicator()
    return "💤" -- Idle/sleeping indicator
end

-- Task 10.2: Statusline integration

-- Get minimal display string for statusline
function M.get_minimal_display_string()
    if not state.initialized then return "" end

    -- Check if statusline is enabled
    if not (state.config.integration and state.config.integration.statusline) then return "" end

    local status = M.get_branch_status()

    if not status then return M.format_idle_indicator() end

    -- Active exploration vs idle
    if status.state == "exploring" then
        return M.format_active_exploration(status.branch_id, status.depth, status.total)
    else
        return M.format_idle_indicator()
    end
end

-- Register statusline component (for lualine, staline, etc.)
function M.register_statusline_component()
    -- This is a simple function that other plugins can call
    -- Example for lualine:
    --   sections = { lualine_c = { require('spaghetti-comb-v2.ui.statusline').get_minimal_display_string } }
    return M.get_minimal_display_string
end

-- Update exploration state (called by navigation events)
function M.update_exploration_state()
    -- State is managed by history manager, we just read it
    return M.get_branch_status()
end

-- Check if actively exploring
function M.is_actively_exploring()
    local status = M.get_branch_status()
    return status and status.state == "exploring"
end

-- Calculate exploration timeout (delegates to history manager)
function M.calculate_exploration_timeout()
    local history_manager = require("spaghetti-comb-v2.history.manager")
    return history_manager.determine_exploration_state()
end

-- Get current state (for testing)
function M.get_state() return state end

-- Reset state (for testing)
function M.reset()
    state = {
        config = state.config,
        initialized = state.initialized,
    }
end

return M
