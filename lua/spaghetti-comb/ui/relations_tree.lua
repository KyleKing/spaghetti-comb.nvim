-- Floating tree for codanna relation results, sibling to the trail-shaped
-- floating_tree; reuses ui.preview and the same window geometry. Children are
-- fetched once on open; deeper exploration re-roots with <C-]>.
local M = {}

-- Module state
local state = {
    config = nil,
    initialized = false,
    buffer = nil,
    window = nil,
    preview_module = nil,
    root = nil,
    rows = nil,
    selected_index = nil,
    namespace = nil,
    on_jump = nil,
    on_reroot = nil,
    visible = false,
}

local TREE_CHARS = {
    branch = "├",
    last_branch = "└",
    horizontal = "─",
}

---@class RelationsRoot
---@field name string Queried symbol name
---@field kind string|nil Symbol kind when the substrate resolved it
---@field file_path string|nil File defining the symbol
---@field line integer|nil Definition line

---@class RelationsGroup
---@field label string Group heading ("Callers", "Depth 2", ...)
---@field items RelationItem[]

---@class RelationsRow
---@field row_type "root"|"group"|"item"
---@field text string Rendered line
---@field item RelationItem|nil Location-carrying row data for jump/reroot/preview

-- Setup the relations tree
---@param config table|nil
function M.setup(config)
    state.config = config or {}
    state.initialized = true
    state.namespace = vim.api.nvim_create_namespace("spaghetti_comb_relations")
    state.preview_module = require("spaghetti-comb.ui.preview")
    M.apply_color_scheme()
end

-- Build the flat row list the buffer renders and the cursor walks.
---@param root RelationsRoot
---@param groups RelationsGroup[]
---@return RelationsRow[]
function M._build_rows(root, groups)
    local root_item = nil
    if root.file_path and root.file_path ~= "" then
        root_item = { name = root.name, file_path = root.file_path, line = root.line or 1 }
    end

    local rows = {
        { row_type = "root", text = M._format_root(root), item = root_item },
    }
    for _, group in ipairs(groups) do
        table.insert(rows, {
            row_type = "group",
            text = string.format("  %s (%d)", group.label, #group.items),
        })
        for i, item in ipairs(group.items) do
            table.insert(rows, {
                row_type = "item",
                text = M._format_item(item, i == #group.items),
                item = item,
            })
        end
    end
    return rows
end

---@param root RelationsRoot
---@return string
function M._format_root(root)
    local text = "◆ " .. root.name
    if root.kind then text = text .. "  (" .. root.kind .. ")" end
    if root.file_path and root.file_path ~= "" then
        text = text .. "  " .. vim.fn.fnamemodify(root.file_path, ":t") .. ":" .. (root.line or 1)
    end
    return text
end

---@param item RelationItem
---@param is_last boolean
---@return string
function M._format_item(item, is_last)
    local prefix = is_last and (TREE_CHARS.last_branch .. TREE_CHARS.horizontal .. " ")
        or (TREE_CHARS.branch .. TREE_CHARS.horizontal .. " ")
    local text = "  " .. prefix .. (item.name or "unknown")
    if item.kind then text = text .. " (" .. item.kind .. ")" end
    if item.file_path and item.file_path ~= "" then
        text = text .. "  " .. vim.fn.fnamemodify(item.file_path, ":t") .. ":" .. (item.line or 1)
    end
    return text
end

-- Show the relations tree. `on_jump(item)` fires on <CR>, `on_reroot(item)` on
-- <C-]>; both receive the row's RelationItem (or the root's location stub).
---@param root RelationsRoot
---@param groups RelationsGroup[]
---@param opts {title: string|nil, on_jump: fun(item: RelationItem)|nil, on_reroot: fun(item: RelationItem)|nil}|nil
---@return boolean success
---@return string message
function M.show(root, groups, opts)
    if not state.initialized then return false, "Relations tree not initialized" end
    opts = opts or {}

    M.hide()

    state.root = root
    state.rows = M._build_rows(root, groups)
    state.on_jump = opts.on_jump
    state.on_reroot = opts.on_reroot

    state.selected_index = 1
    for i, row in ipairs(state.rows) do
        if row.row_type == "item" then
            state.selected_index = i
            break
        end
    end

    M._create_window(opts.title or " Relations ")
    M._render()

    if state.window and vim.api.nvim_win_is_valid(state.window) then
        vim.api.nvim_win_set_cursor(state.window, { state.selected_index, 0 })
    end
    M._update_preview()

    return true, "Relations tree displayed"
end

-- Hide the tree and its preview
function M.hide()
    if state.window and vim.api.nvim_win_is_valid(state.window) then vim.api.nvim_win_close(state.window, true) end
    if state.buffer and vim.api.nvim_buf_is_valid(state.buffer) then
        vim.api.nvim_buf_delete(state.buffer, { force = true })
    end
    if state.preview_module then state.preview_module.hide_preview() end

    state.window = nil
    state.buffer = nil
    state.visible = false
end

-- Create the tree floating window (left half, matching floating_tree)
---@param title string
function M._create_window(title)
    state.buffer = vim.api.nvim_create_buf(false, true)
    vim.bo[state.buffer].bufhidden = "wipe"
    vim.bo[state.buffer].filetype = "spaghetti-comb-relations"

    local width = math.floor(vim.o.columns * 0.5)
    local height = math.floor(vim.o.lines * 0.7)

    state.window = vim.api.nvim_open_win(state.buffer, true, {
        relative = "editor",
        width = width,
        height = height,
        row = math.floor((vim.o.lines - height) / 2),
        col = 2,
        style = "minimal",
        border = "rounded",
        title = title,
        title_pos = "center",
    })

    vim.wo[state.window].wrap = false
    vim.wo[state.window].cursorline = true

    M._set_keymaps()
    state.visible = true
end

-- Write rendered rows into the buffer and apply highlights
function M._render()
    if not state.buffer or not vim.api.nvim_buf_is_valid(state.buffer) then return end

    local lines = {}
    for _, row in ipairs(state.rows) do
        table.insert(lines, row.text)
    end

    vim.bo[state.buffer].modifiable = true
    vim.api.nvim_buf_set_lines(state.buffer, 0, -1, false, lines)
    vim.bo[state.buffer].modifiable = false

    vim.api.nvim_buf_clear_namespace(state.buffer, state.namespace, 0, -1)
    for i, row in ipairs(state.rows) do
        local group = row.row_type == "root" and "SpaghettiCombRelationsRoot"
            or row.row_type == "group" and "SpaghettiCombRelationsGroup"
            or nil
        if group then vim.api.nvim_buf_add_highlight(state.buffer, state.namespace, group, i - 1, 0, -1) end
    end
end

function M._set_keymaps()
    local opts = { noremap = true, silent = true, buffer = state.buffer }

    vim.keymap.set("n", "q", function() M.hide() end, opts)
    vim.keymap.set("n", "<Esc>", function() M.hide() end, opts)
    vim.keymap.set("n", "j", function() M._move_selection(1) end, opts)
    vim.keymap.set("n", "k", function() M._move_selection(-1) end, opts)
    vim.keymap.set("n", "<Down>", function() M._move_selection(1) end, opts)
    vim.keymap.set("n", "<Up>", function() M._move_selection(-1) end, opts)
    vim.keymap.set("n", "<CR>", function() M._jump_to_selected() end, opts)
    vim.keymap.set("n", "<C-]>", function() M._reroot_selected() end, opts)
end

---@param delta integer
function M._move_selection(delta)
    if not state.rows or #state.rows == 0 then return end

    state.selected_index = (state.selected_index or 1) + delta
    state.selected_index = math.max(1, math.min(#state.rows, state.selected_index))

    if state.window and vim.api.nvim_win_is_valid(state.window) then
        vim.api.nvim_win_set_cursor(state.window, { state.selected_index, 0 })
    end
    M._update_preview()
end

function M._jump_to_selected()
    local row = state.rows and state.rows[state.selected_index]
    if not row or not row.item then return end
    local on_jump = state.on_jump
    M.hide()
    if on_jump then on_jump(row.item) end
end

function M._reroot_selected()
    local row = state.rows and state.rows[state.selected_index]
    if row and row.item and state.on_reroot then state.on_reroot(row.item) end
end

-- Preview the selected row's location on the right side, like floating_tree
function M._update_preview()
    if not state.preview_module then return end
    local row = state.rows and state.rows[state.selected_index]
    if not row or not row.item or not row.item.file_path or row.item.file_path == "" then return end

    local file_path = require("spaghetti-comb.ui.picker")._resolve_hit_path(row.item.file_path)

    local tree_width = math.floor(vim.o.columns * 0.5)
    local preview_width = vim.o.columns - tree_width - 6
    local preview_height = math.floor(vim.o.lines * 0.7)

    state.preview_module.show_preview({ file_path = file_path, position = { line = row.item.line or 1, column = 1 } }, {
        width = preview_width,
        height = preview_height,
        row = math.floor((vim.o.lines - preview_height) / 2),
        col = tree_width + 4,
        context_lines = 10,
    })
end

-- Highlight groups for the root symbol and group headers
function M.apply_color_scheme()
    vim.api.nvim_set_hl(0, "SpaghettiCombRelationsRoot", { fg = "#61AFEF", bold = true })
    vim.api.nvim_set_hl(0, "SpaghettiCombRelationsGroup", { fg = "#C678DD", bold = true })
end

-- Check if the tree is visible
function M.is_visible() return state.visible or false end

-- Get current state (for testing)
function M.get_state() return state end

-- Reset state (for testing)
function M.reset()
    M.hide()
    state = {
        config = state.config,
        initialized = state.initialized,
        buffer = nil,
        window = nil,
        preview_module = state.preview_module,
        root = nil,
        rows = nil,
        selected_index = nil,
        namespace = state.namespace,
        on_jump = nil,
        on_reroot = nil,
        visible = false,
    }
end

return M
