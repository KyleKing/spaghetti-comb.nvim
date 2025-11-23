-- Code preview functionality
local M = {}

-- Module state
local state = {
    config = nil,
    initialized = false,
    preview_buffer = nil,
    preview_window = nil,
    namespace = nil,
}

-- Setup preview system
function M.setup(config)
    state.config = config or {}
    state.initialized = true
    state.namespace = vim.api.nvim_create_namespace("spaghetti_comb_preview")
end

-- Task 7.3: Preview functionality

-- Extract code context around a location
function M.extract_code_context(location, context_lines)
    if not location or not location.file_path then return nil, "Invalid location" end

    context_lines = context_lines or 5

    -- Check if file exists and is readable
    if vim.fn.filereadable(location.file_path) == 0 then return nil, "File not readable: " .. location.file_path end

    -- Read file lines
    local lines = vim.fn.readfile(location.file_path)
    if not lines or #lines == 0 then return nil, "Empty or invalid file" end

    local target_line = location.position and location.position.line or 1
    local start_line = math.max(1, target_line - context_lines)
    local end_line = math.min(#lines, target_line + context_lines)

    -- Extract context
    local context = {
        file_path = location.file_path,
        target_line = target_line,
        start_line = start_line,
        end_line = end_line,
        lines = {},
        full_content = lines,
    }

    for i = start_line, end_line do
        table.insert(context.lines, { line_num = i, content = lines[i], is_target = i == target_line })
    end

    return context, nil
end

-- Show preview in a floating window
function M.show_preview(location, opts)
    if not state.initialized then return false, "Preview not initialized" end
    if not location then return false, "Invalid location" end

    opts = opts or {}
    local context_lines = opts.context_lines or 5

    -- Extract context
    local context, err = M.extract_code_context(location, context_lines)
    if not context then return false, err end

    -- Create or update preview window
    if not state.preview_window or not vim.api.nvim_win_is_valid(state.preview_window) then
        M._create_preview_window(opts)
    end

    -- Update preview content
    M._update_preview_content(context)

    return true, context
end

-- Update preview with new location
function M.update_preview(location, opts)
    if not state.visible then return M.show_preview(location, opts) end

    return M.show_preview(location, opts)
end

-- Hide preview window
function M.hide_preview()
    if state.preview_window and vim.api.nvim_win_is_valid(state.preview_window) then
        vim.api.nvim_win_close(state.preview_window, true)
    end

    if state.preview_buffer and vim.api.nvim_buf_is_valid(state.preview_buffer) then
        vim.api.nvim_buf_delete(state.preview_buffer, { force = true })
    end

    state.preview_window = nil
    state.preview_buffer = nil
    state.visible = false
end

-- Create preview floating window
function M._create_preview_window(opts)
    opts = opts or {}

    -- Create buffer if needed
    if not state.preview_buffer or not vim.api.nvim_buf_is_valid(state.preview_buffer) then
        state.preview_buffer = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_option(state.preview_buffer, "bufhidden", "wipe")
        vim.api.nvim_buf_set_option(state.preview_buffer, "filetype", "spaghetti-comb-preview")
    end

    -- Calculate window dimensions
    local width = opts.width or math.floor(vim.o.columns * 0.4)
    local height = opts.height or math.floor(vim.o.lines * 0.5)
    local row = opts.row or 2
    local col = opts.col or (vim.o.columns - width - 2)

    -- Create floating window
    local win_opts = {
        relative = opts.relative or "editor",
        width = width,
        height = height,
        row = row,
        col = col,
        style = "minimal",
        border = "rounded",
        title = " Preview ",
        title_pos = "center",
    }

    state.preview_window = vim.api.nvim_open_win(state.preview_buffer, false, win_opts)

    -- Set window options
    vim.api.nvim_win_set_option(state.preview_window, "wrap", false)
    vim.api.nvim_win_set_option(state.preview_window, "number", true)
    vim.api.nvim_win_set_option(state.preview_window, "relativenumber", false)

    state.visible = true
end

-- Update preview content
function M._update_preview_content(context)
    if not state.preview_buffer or not vim.api.nvim_buf_is_valid(state.preview_buffer) then return end

    -- Build preview lines
    local lines = {}
    for _, line_info in ipairs(context.lines) do
        local prefix = line_info.is_target and "▶ " or "  "
        table.insert(lines, prefix .. line_info.content)
    end

    -- Update buffer
    vim.api.nvim_buf_set_option(state.preview_buffer, "modifiable", true)
    vim.api.nvim_buf_set_lines(state.preview_buffer, 0, -1, false, lines)
    vim.api.nvim_buf_set_option(state.preview_buffer, "modifiable", false)

    -- Apply syntax highlighting based on file type
    local filetype = vim.filetype.match({ filename = context.file_path })
    if filetype then vim.api.nvim_buf_set_option(state.preview_buffer, "filetype", filetype) end

    -- Highlight target line
    M._highlight_target_line(context)

    -- Scroll to target line
    if state.preview_window and vim.api.nvim_win_is_valid(state.preview_window) then
        local target_index = nil
        for i, line_info in ipairs(context.lines) do
            if line_info.is_target then
                target_index = i
                break
            end
        end

        if target_index then vim.api.nvim_win_set_cursor(state.preview_window, { target_index, 0 }) end
    end
end

-- Highlight the target line in preview
function M._highlight_target_line(context)
    if not state.preview_buffer or not vim.api.nvim_buf_is_valid(state.preview_buffer) then return end

    vim.api.nvim_buf_clear_namespace(state.preview_buffer, state.namespace, 0, -1)

    for i, line_info in ipairs(context.lines) do
        if line_info.is_target then
            vim.api.nvim_buf_add_highlight(state.preview_buffer, state.namespace, "CursorLine", i - 1, 0, -1)
            break
        end
    end
end

-- Check if preview is visible
function M.is_visible() return state.visible or false end

-- Get current state (for testing)
function M.get_state() return state end

-- Reset state (for testing)
function M.reset()
    M.hide_preview()
    state = {
        config = state.config,
        initialized = state.initialized,
        preview_buffer = nil,
        preview_window = nil,
        namespace = state.namespace,
        visible = false,
    }
end

return M
