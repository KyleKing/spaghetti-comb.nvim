-- Branch history floating window with unicode tree
local M = {}

-- Module state
local state = {
    config = nil,
    initialized = false,
    tree_buffer = nil,
    tree_window = nil,
    preview_module = nil,
    current_trail = nil,
    selected_index = nil,
    namespace = nil,
}

-- Unicode box-drawing characters
local TREE_CHARS = {
    vertical = "│",
    horizontal = "─",
    branch = "├",
    last_branch = "└",
    continuation = "│ ",
    space = "  ",
}

-- Setup the floating tree system
function M.setup(config)
    state.config = config or {}
    state.initialized = true
    state.namespace = vim.api.nvim_create_namespace("spaghetti_comb_tree")

    -- Load preview module
    state.preview_module = require("spaghetti-comb.ui.preview")

    -- Set up color scheme
    M.apply_color_scheme()
end

-- Task 7.2: Window management

-- Show branch history in floating tree window
function M.show_branch_history()
    if not state.initialized then return false, "Tree view not initialized" end

    -- Get current navigation trail
    local history_manager = require("spaghetti-comb.history.manager")
    local trail = history_manager.get_current_trail()

    if not trail or #trail.entries == 0 then
        vim.notify("No navigation history available", vim.log.levels.INFO)
        return false, "No navigation history"
    end

    state.current_trail = trail
    state.selected_index = trail.current_index

    -- Create tree and preview windows
    M._create_tree_window()
    M.update_tree_display()

    return true, "Tree view displayed"
end

-- Hide tree window
function M.hide()
    if state.tree_window and vim.api.nvim_win_is_valid(state.tree_window) then
        vim.api.nvim_win_close(state.tree_window, true)
    end

    if state.tree_buffer and vim.api.nvim_buf_is_valid(state.tree_buffer) then
        vim.api.nvim_buf_delete(state.tree_buffer, { force = true })
    end

    -- Hide preview pane
    if state.preview_module then state.preview_module.hide_preview() end

    state.tree_window = nil
    state.tree_buffer = nil
    state.visible = false
end

-- Toggle tree window visibility
function M.toggle()
    if state.visible then
        M.hide()
    else
        M.show_branch_history()
    end
end

-- Create the tree floating window
function M._create_tree_window()
    -- Create buffer
    state.tree_buffer = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_option(state.tree_buffer, "bufhidden", "wipe")
    vim.api.nvim_buf_set_option(state.tree_buffer, "filetype", "spaghetti-comb-tree")

    -- Calculate window dimensions (left side for tree)
    local width = math.floor(vim.o.columns * 0.5)
    local height = math.floor(vim.o.lines * 0.7)
    local row = math.floor((vim.o.lines - height) / 2)
    local col = 2

    -- Create floating window
    local opts = {
        relative = "editor",
        width = width,
        height = height,
        row = row,
        col = col,
        style = "minimal",
        border = "rounded",
        title = " Navigation History Tree ",
        title_pos = "center",
    }

    state.tree_window = vim.api.nvim_open_win(state.tree_buffer, true, opts)

    -- Set window options
    vim.api.nvim_win_set_option(state.tree_window, "wrap", false)
    vim.api.nvim_win_set_option(state.tree_window, "cursorline", true)

    -- Set up key mappings
    M.handle_vim_motions()

    state.visible = true
end

-- Task 7.1: Unicode tree rendering

-- Render unicode tree from branches
function M.render_unicode_tree(trail)
    if not trail or #trail.entries == 0 then return { "No navigation history" } end

    local lines = {}
    local bookmarks = require("spaghetti-comb.history.bookmarks")

    -- Build tree structure
    for i, entry in ipairs(trail.entries) do
        local line = M._format_tree_entry(entry, i, trail.current_index, bookmarks)
        table.insert(lines, line)
    end

    return lines
end

-- Format a single tree entry
function M._format_tree_entry(entry, index, current_index, bookmarks)
    local prefix = ""

    -- Add tree structure
    if index == 1 then
        prefix = "  "
    elseif index == current_index then
        prefix = TREE_CHARS.last_branch .. TREE_CHARS.horizontal .. " "
    else
        prefix = TREE_CHARS.branch .. TREE_CHARS.horizontal .. " "
    end

    -- Add entry type icon
    local icon = "  "
    if index == current_index then
        icon = "▶ "
    elseif entry.is_bookmarked or (bookmarks and bookmarks.is_bookmarked and bookmarks.is_bookmarked(entry)) then
        icon = "⭐ "
    elseif entry.is_frequent or (bookmarks and bookmarks.is_frequent and bookmarks.is_frequent(entry)) then
        icon = "🔥 "
    end

    -- Format file location
    local filename = vim.fn.fnamemodify(entry.file_path, ":t")
    local location = string.format("%s:%d", filename, entry.position.line)

    -- Add jump type if not manual
    local jump_info = entry.jump_type ~= "manual" and string.format(" (%s)", entry.jump_type) or ""

    return prefix .. icon .. location .. jump_info
end

-- Update tree display
function M.update_tree_display()
    if not state.visible or not state.tree_buffer then return end
    if not state.current_trail then return end

    -- Render tree
    local lines = M.render_unicode_tree(state.current_trail)

    -- Update buffer content
    vim.api.nvim_buf_set_option(state.tree_buffer, "modifiable", true)
    vim.api.nvim_buf_set_lines(state.tree_buffer, 0, -1, false, lines)
    vim.api.nvim_buf_set_option(state.tree_buffer, "modifiable", false)

    -- Highlight active branch
    M.highlight_active_branch()

    -- Update preview if selected
    if state.selected_index then M.update_preview_pane(state.selected_index) end
end

-- Highlight active branch and important nodes
function M.highlight_active_branch()
    if not state.tree_buffer or not vim.api.nvim_buf_is_valid(state.tree_buffer) then return end
    if not state.current_trail then return end

    vim.api.nvim_buf_clear_namespace(state.tree_buffer, state.namespace, 0, -1)

    -- Highlight current entry
    if state.current_trail.current_index and state.current_trail.current_index > 0 then
        local line_num = state.current_trail.current_index - 1
        vim.api.nvim_buf_add_highlight(state.tree_buffer, state.namespace, "SpaghettiCombTreeCurrent", line_num, 0, -1)
    end

    -- Mark bookmarked and frequent nodes
    M.mark_bookmarked_nodes()
    M.mark_important_nodes()
end

-- Mark bookmarked nodes with special highlighting
function M.mark_bookmarked_nodes()
    if not state.tree_buffer or not state.current_trail then return end

    local bookmarks = require("spaghetti-comb.history.bookmarks")

    for i, entry in ipairs(state.current_trail.entries) do
        if entry.is_bookmarked or (bookmarks.is_bookmarked and bookmarks.is_bookmarked(entry)) then
            vim.api.nvim_buf_add_highlight(state.tree_buffer, state.namespace, "SpaghettiCombTreeBookmark", i - 1, 0, -1)
        end
    end
end

-- Mark important/frequent nodes
function M.mark_important_nodes()
    if not state.tree_buffer or not state.current_trail then return end

    local bookmarks = require("spaghetti-comb.history.bookmarks")

    for i, entry in ipairs(state.current_trail.entries) do
        if entry.is_frequent or (bookmarks.is_frequent and bookmarks.is_frequent(entry)) then
            vim.api.nvim_buf_add_highlight(state.tree_buffer, state.namespace, "SpaghettiCombTreeFrequent", i - 1, 0, -1)
        end
    end
end

-- Task 7.3: Navigation and preview

-- Handle vim motions in tree window
function M.handle_vim_motions()
    if not state.tree_buffer then return end

    local opts = { noremap = true, silent = true, buffer = state.tree_buffer }

    -- Close window
    vim.keymap.set("n", "q", function() M.hide() end, opts)
    vim.keymap.set("n", "<Esc>", function() M.hide() end, opts)

    -- Navigate tree
    vim.keymap.set("n", "j", function() M._move_selection(1) end, opts)
    vim.keymap.set("n", "k", function() M._move_selection(-1) end, opts)
    vim.keymap.set("n", "<Down>", function() M._move_selection(1) end, opts)
    vim.keymap.set("n", "<Up>", function() M._move_selection(-1) end, opts)

    -- Jump to selected node
    vim.keymap.set("n", "<CR>", function() M._jump_to_selected() end, opts)

    -- Refresh tree
    vim.keymap.set("n", "r", function() M.update_tree_display() end, opts)
end

-- Move selection in tree
function M._move_selection(delta)
    if not state.current_trail or #state.current_trail.entries == 0 then return end

    state.selected_index = state.selected_index or state.current_trail.current_index or 1
    state.selected_index = state.selected_index + delta

    -- Clamp to valid range
    state.selected_index = math.max(1, math.min(#state.current_trail.entries, state.selected_index))

    -- Update cursor position
    if state.tree_window and vim.api.nvim_win_is_valid(state.tree_window) then
        vim.api.nvim_win_set_cursor(state.tree_window, { state.selected_index, 0 })
    end

    -- Update preview
    M.update_preview_pane(state.selected_index)
end

-- Jump to selected tree node
function M._jump_to_selected()
    if not state.current_trail or not state.selected_index then return end

    local entry = state.current_trail.entries[state.selected_index]
    if not entry then return end

    -- Hide tree view
    M.hide()

    -- Jump to location
    vim.cmd(string.format("edit +%d %s", entry.position.line, entry.file_path))
    vim.api.nvim_win_set_cursor(0, { entry.position.line, entry.position.column - 1 })
end

-- Select specific branch node
function M.select_branch_node(index)
    if not state.current_trail or not state.current_trail.entries[index] then return false end

    state.selected_index = index
    M.update_preview_pane(index)

    return true
end

-- Update preview pane for selected node
function M.update_preview_pane(index)
    if not state.current_trail or not state.preview_module then return end

    local entry = state.current_trail.entries[index]
    if not entry then return end

    -- Calculate preview window position (right side)
    local tree_width = math.floor(vim.o.columns * 0.5)
    local preview_width = vim.o.columns - tree_width - 6
    local preview_height = math.floor(vim.o.lines * 0.7)
    local row = math.floor((vim.o.lines - preview_height) / 2)
    local col = tree_width + 4

    -- Show preview
    state.preview_module.show_preview(entry, {
        width = preview_width,
        height = preview_height,
        row = row,
        col = col,
        context_lines = 10,
    })
end

-- Task 7.1: Visual styling

-- Apply color scheme for tree visualization
function M.apply_color_scheme()
    -- Define highlight groups for tree elements
    vim.api.nvim_set_hl(0, "SpaghettiCombTreeCurrent", { fg = "#61AFEF", bold = true })
    vim.api.nvim_set_hl(0, "SpaghettiCombTreeBookmark", { fg = "#E5C07B" })
    vim.api.nvim_set_hl(0, "SpaghettiCombTreeFrequent", { fg = "#E06C75" })
    vim.api.nvim_set_hl(0, "SpaghettiCombTreeNormal", { fg = "#ABB2BF" })
    vim.api.nvim_set_hl(0, "SpaghettiCombTreeBranch", { fg = "#C678DD" })
end

-- Check if tree is visible
function M.is_visible() return state.visible or false end

-- Get current state (for testing)
function M.get_state() return state end

-- Reset state (for testing)
function M.reset()
    M.hide()
    state = {
        config = state.config,
        initialized = state.initialized,
        tree_buffer = nil,
        tree_window = nil,
        preview_module = state.preview_module,
        current_trail = nil,
        selected_index = nil,
        namespace = state.namespace,
        visible = false,
    }
end

return M
