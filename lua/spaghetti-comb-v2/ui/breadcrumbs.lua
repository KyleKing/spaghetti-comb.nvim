-- Visual breadcrumb rendering with collapse/expand
local M = {}

-- Module state
local state = {
    config = nil,
    initialized = false,
    visible = false,
    current_trail = nil,
    focused_index = nil,
    buffer = nil,
    window = nil,
    namespace = nil,
}

-- Setup the breadcrumb system
function M.setup(config)
    state.config = config or {}
    state.initialized = true
    state.namespace = vim.api.nvim_create_namespace("spaghetti_comb_breadcrumbs")

    -- Set up highlight groups
    M.set_highlight_groups()
end

-- Task 6.1: Hotkey-only breadcrumb display

-- Show breadcrumbs on hotkey press
function M.show_on_hotkey()
    if not state.initialized then return false, "Breadcrumbs not initialized" end

    -- Get current navigation trail from history manager
    local history_manager = require("spaghetti-comb-v2.history.manager")
    local trail = history_manager.get_current_trail()

    if not trail or #trail.entries == 0 then
        vim.notify("No navigation history available", vim.log.levels.INFO)
        return false, "No navigation history"
    end

    state.current_trail = trail
    M._create_breadcrumb_window()
    M.update_display(trail)
    state.visible = true

    return true, "Breadcrumbs displayed"
end

-- Hide breadcrumbs
function M.hide()
    if not state.visible then return end

    if state.window and vim.api.nvim_win_is_valid(state.window) then vim.api.nvim_win_close(state.window, true) end

    if state.buffer and vim.api.nvim_buf_is_valid(state.buffer) then
        vim.api.nvim_buf_delete(state.buffer, { force = true })
    end

    state.visible = false
    state.window = nil
    state.buffer = nil
end

-- Toggle breadcrumb visibility
function M.toggle()
    if state.visible then
        M.hide()
    else
        M.show_on_hotkey()
    end
end

-- Update breadcrumb display with new trail
function M.update_display(trail)
    if not state.visible or not state.buffer then return end
    if not trail or #trail.entries == 0 then return end

    state.current_trail = trail

    -- Build breadcrumb lines
    local lines = M._build_breadcrumb_lines(trail)

    -- Update buffer content
    vim.api.nvim_buf_set_option(state.buffer, "modifiable", true)
    vim.api.nvim_buf_set_lines(state.buffer, 0, -1, false, lines)
    vim.api.nvim_buf_set_option(state.buffer, "modifiable", false)

    -- Apply highlighting
    M._apply_highlights(trail)
end

-- Create the breadcrumb floating window
function M._create_breadcrumb_window()
    -- Create buffer
    state.buffer = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_option(state.buffer, "bufhidden", "wipe")
    vim.api.nvim_buf_set_option(state.buffer, "filetype", "spaghetti-comb-breadcrumbs")

    -- Calculate window dimensions
    local width = math.min(100, vim.o.columns - 4)
    local height = math.min(3, vim.o.lines - 4)
    local row = 0
    local col = math.floor((vim.o.columns - width) / 2)

    -- Create floating window
    local opts = {
        relative = "editor",
        width = width,
        height = height,
        row = row,
        col = col,
        style = "minimal",
        border = "rounded",
        title = " Navigation Breadcrumbs ",
        title_pos = "center",
    }

    state.window = vim.api.nvim_open_win(state.buffer, true, opts)

    -- Set window options
    vim.api.nvim_win_set_option(state.window, "wrap", false)
    vim.api.nvim_win_set_option(state.window, "cursorline", true)

    -- Set up key mappings for the breadcrumb window
    M._setup_keymaps()
end

-- Build breadcrumb display lines from trail
function M._build_breadcrumb_lines(trail)
    if not trail or #trail.entries == 0 then return { "No navigation history" } end

    local lines = {}
    local separator = state.config.display and state.config.display.separator or " › "
    local max_items = state.config.display and state.config.display.max_items or 10

    -- Build breadcrumb path
    local breadcrumb_parts = {}
    local start_index = math.max(1, trail.current_index - max_items + 1)

    for i = start_index, trail.current_index do
        local entry = trail.entries[i]
        if entry then
            local display_name = M._format_entry_display(entry, i == trail.current_index)
            table.insert(breadcrumb_parts, display_name)
        end
    end

    -- Join breadcrumb parts
    local breadcrumb_line = table.concat(breadcrumb_parts, separator)

    -- Add position indicator
    local position_info = string.format("  [%d/%d]", trail.current_index, #trail.entries)

    table.insert(lines, breadcrumb_line)
    table.insert(lines, "")
    table.insert(lines, position_info .. "  Press 'q' to close, 'j/k' to navigate")

    return lines
end

-- Format a single entry for display
function M._format_entry_display(entry, is_current)
    local filename = vim.fn.fnamemodify(entry.file_path, ":t") -- Get basename
    local location = string.format("%s:%d", filename, entry.position.line)

    if is_current then
        return "▶ " .. location
    elseif entry.is_bookmarked then
        return "⭐ " .. location
    elseif entry.is_frequent then
        return "🔥 " .. location
    else
        return location
    end
end

-- Apply syntax highlighting to breadcrumbs
function M._apply_highlights(trail)
    if not state.buffer or not vim.api.nvim_buf_is_valid(state.buffer) then return end

    vim.api.nvim_buf_clear_namespace(state.buffer, state.namespace, 0, -1)

    -- Highlight current entry
    -- Additional highlighting can be added here for bookmarked/frequent entries
end

-- Set up key mappings for breadcrumb window
function M._setup_keymaps()
    if not state.buffer then return end

    local opts = { noremap = true, silent = true, buffer = state.buffer }

    -- Close window
    vim.keymap.set("n", "q", function() M.hide() end, opts)
    vim.keymap.set("n", "<Esc>", function() M.hide() end, opts)

    -- Navigate breadcrumbs
    vim.keymap.set("n", "j", function() M._navigate_next() end, opts)
    vim.keymap.set("n", "k", function() M._navigate_prev() end, opts)
    vim.keymap.set("n", "<Down>", function() M._navigate_next() end, opts)
    vim.keymap.set("n", "<Up>", function() M._navigate_prev() end, opts)

    -- Jump to selected breadcrumb
    vim.keymap.set("n", "<CR>", function() M._jump_to_focused() end, opts)

    -- Focus management (for collapse/expand)
    vim.keymap.set("n", "<Tab>", function() M._cycle_focus() end, opts)
end

-- Navigate to next breadcrumb
function M._navigate_next()
    if not state.current_trail then return end

    local history_manager = require("spaghetti-comb-v2.history.manager")
    history_manager.navigate_forward()

    -- Refresh display
    local trail = history_manager.get_current_trail()
    if trail then M.update_display(trail) end
end

-- Navigate to previous breadcrumb
function M._navigate_prev()
    if not state.current_trail then return end

    local history_manager = require("spaghetti-comb-v2.history.manager")
    history_manager.navigate_backward()

    -- Refresh display
    local trail = history_manager.get_current_trail()
    if trail then M.update_display(trail) end
end

-- Jump to the focused breadcrumb entry
function M._jump_to_focused()
    if not state.current_trail or not state.current_trail.entries[state.current_trail.current_index] then return end

    local entry = state.current_trail.entries[state.current_trail.current_index]

    -- Close breadcrumbs
    M.hide()

    -- Jump to location
    vim.cmd(string.format("edit +%d %s", entry.position.line, entry.file_path))
    vim.api.nvim_win_set_cursor(0, { entry.position.line, entry.position.column - 1 })
end

-- Task 6.2: Collapsible breadcrumb interface

-- Focus on a specific item
function M.focus_item(index)
    if not state.current_trail or not state.current_trail.entries[index] then return false end

    state.focused_index = index

    if state.config.display and state.config.display.collapse_unfocused then
        M.collapse_unfocused()
        M.expand_neighbors(index)
    end

    return true
end

-- Collapse unfocused items
function M.collapse_unfocused()
    -- This will be implemented when we add visual collapse indicators
    -- For now, we'll prepare the structure
    if not state.current_trail then return end

    -- Implementation will modify display to show collapsed items
end

-- Expand neighbors of focused item
function M.expand_neighbors(focused_index)
    -- Show focused item and immediate neighbors
    if not state.current_trail then return end

    -- Implementation will modify display to show expanded neighbors
end

-- Cycle focus through breadcrumb items
function M._cycle_focus()
    if not state.current_trail then return end

    local next_index = (state.focused_index or 0) + 1
    if next_index > #state.current_trail.entries then next_index = 1 end

    M.focus_item(next_index)
    M.update_display(state.current_trail)
end

-- Task 6.3: Visual distinction for entry types

-- Set up highlight groups for different entry types
function M.set_highlight_groups()
    -- Define highlight groups for breadcrumb elements
    vim.api.nvim_set_hl(0, "SpaghettiCombBreadcrumbCurrent", { fg = "#61AFEF", bold = true })
    vim.api.nvim_set_hl(0, "SpaghettiCombBreadcrumbBookmark", { fg = "#E5C07B" })
    vim.api.nvim_set_hl(0, "SpaghettiCombBreadcrumbFrequent", { fg = "#E06C75" })
    vim.api.nvim_set_hl(0, "SpaghettiCombBreadcrumbNormal", { fg = "#ABB2BF" })
    vim.api.nvim_set_hl(0, "SpaghettiCombBreadcrumbBranchPoint", { fg = "#C678DD" })
    vim.api.nvim_set_hl(0, "SpaghettiCombBreadcrumbLineShifted", { fg = "#D19A66", italic = true })
end

-- Configure display options
function M.configure_display_options(opts)
    if not state.config then state.config = {} end
    if not state.config.display then state.config.display = {} end

    state.config.display = vim.tbl_deep_extend("force", state.config.display, opts or {})
end

-- Check if breadcrumbs are visible
function M.is_visible() return state.visible end

-- Get current state (for testing/debugging)
function M.get_state() return state end

-- Reset state (for testing)
function M.reset()
    M.hide()
    state = {
        config = state.config,
        initialized = state.initialized,
        visible = false,
        current_trail = nil,
        focused_index = nil,
        buffer = nil,
        window = nil,
        namespace = state.namespace,
    }
end

return M
