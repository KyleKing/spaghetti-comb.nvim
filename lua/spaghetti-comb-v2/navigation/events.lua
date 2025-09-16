-- Navigation event handling system
local M = {}

-- Dependencies
local history_manager = require("spaghetti-comb-v2.history.manager")
local project_utils = require("spaghetti-comb-v2.utils.project")
local debug_utils = require("spaghetti-comb-v2.utils.debug")

-- Module state
local state = {
    config = nil,
    initialized = false,
    debounce_timer = nil,
    last_cursor_position = nil,
    last_buffer = nil,
    last_window = nil,
    pending_jump = nil,
    jump_debounce_ms = 100, -- 100ms debounce for cursor movements
    buffer_change_debounce_ms = 500, -- 500ms debounce for buffer changes
}

-- Jump type classification
local JUMP_TYPES = {
    MANUAL = "manual",
    LSP_DEFINITION = "lsp_definition",
    LSP_REFERENCES = "lsp_references",
    LSP_IMPLEMENTATION = "lsp_implementation",
    LSP_TYPE_DEFINITION = "lsp_type_definition",
    BUFFER_SWITCH = "buffer_switch",
    WINDOW_SWITCH = "window_switch",
    JUMPLIST_BACKWARD = "jumplist_backward",
    JUMPLIST_FORWARD = "jumplist_forward",
}

-- Setup the event handling system
function M.setup(config)
    state.config = config or {}
    state.initialized = true

    -- Set debounce times from config
    if config.history then
        state.jump_debounce_ms = (config.history.jump_debounce_ms or 100)
        state.buffer_change_debounce_ms = (config.history.buffer_change_debounce_ms or 500)
    end

    -- Setup autocmd groups
    M.setup_autocmds()

    debug_utils.info("Navigation event handling system initialized")
end

-- Setup Neovim autocmds for navigation events
function M.setup_autocmds()
    local augroup = vim.api.nvim_create_augroup("SpaghettiCombNavigation", { clear = true })

    -- Cursor movement events
    vim.api.nvim_create_autocmd("CursorMoved", {
        group = augroup,
        callback = function() M.on_cursor_moved() end,
    })

    -- Buffer change events
    vim.api.nvim_create_autocmd("BufEnter", {
        group = augroup,
        callback = function() M.on_buffer_enter() end,
    })

    vim.api.nvim_create_autocmd("BufLeave", {
        group = augroup,
        callback = function() M.on_buffer_leave() end,
    })

    -- Window switch events
    vim.api.nvim_create_autocmd("WinEnter", {
        group = augroup,
        callback = function() M.on_window_enter() end,
    })

    vim.api.nvim_create_autocmd("WinLeave", {
        group = augroup,
        callback = function() M.on_window_leave() end,
    })

    -- LSP events (if LSP integration is enabled)
    if state.config.integration and state.config.integration.lsp then M.setup_lsp_hooks() end

    -- Jumplist events
    vim.api.nvim_create_autocmd("CmdlineLeave", {
        group = augroup,
        callback = function() M.on_cmdline_leave() end,
    })
end

-- Setup LSP-specific event hooks
function M.setup_lsp_hooks()
    -- Hook into LSP requests for definition jumps
    vim.api.nvim_create_autocmd("LspRequest", {
        pattern = "textDocument/definition",
        callback = function(args)
            if args.data and args.data.result then M.on_lsp_definition_jump(args.data.result) end
        end,
    })

    -- Hook into LSP requests for references
    vim.api.nvim_create_autocmd("LspRequest", {
        pattern = "textDocument/references",
        callback = function(args)
            if args.data and args.data.result then M.on_lsp_references_jump(args.data.result) end
        end,
    })

    -- Hook into LSP requests for implementation
    vim.api.nvim_create_autocmd("LspRequest", {
        pattern = "textDocument/implementation",
        callback = function(args)
            if args.data and args.data.result then M.on_lsp_implementation_jump(args.data.result) end
        end,
    })

    -- Hook into LSP requests for type definition
    vim.api.nvim_create_autocmd("LspRequest", {
        pattern = "textDocument/typeDefinition",
        callback = function(args)
            if args.data and args.data.result then M.on_lsp_type_definition_jump(args.data.result) end
        end,
    })
end

-- Cursor movement handler with debouncing
function M.on_cursor_moved()
    if not state.initialized then return end

    -- Cancel existing debounce timer
    if state.debounce_timer then vim.fn.timer_stop(state.debounce_timer) end

    -- Get current position
    local current_pos = vim.api.nvim_win_get_cursor(0)
    local current_buf = vim.api.nvim_get_current_buf()
    local current_win = vim.api.nvim_get_current_win()

    -- Check if this is a significant movement
    if M.is_significant_cursor_movement(current_pos, current_buf, current_win) then
        -- Schedule debounced jump recording
        state.debounce_timer = vim.fn.timer_start(state.jump_debounce_ms, function()
            M.record_pending_jump(JUMP_TYPES.MANUAL)
            state.debounce_timer = nil
        end)
    end

    -- Update last known position
    state.last_cursor_position = current_pos
    state.last_buffer = current_buf
    state.last_window = current_win
end

-- Check if cursor movement is significant enough to record
function M.is_significant_cursor_movement(new_pos, new_buf, new_win)
    if not state.last_cursor_position then return true end

    -- Always record if buffer or window changed
    if new_buf ~= state.last_buffer or new_win ~= state.last_window then return true end

    -- Check line distance for same buffer/window
    local line_distance = math.abs(new_pos[1] - state.last_cursor_position[1])
    local col_distance = math.abs(new_pos[2] - state.last_cursor_position[2])

    -- Only record if moved more than threshold
    local MIN_LINE_DISTANCE = 3
    local MIN_COL_DISTANCE = 10

    return line_distance >= MIN_LINE_DISTANCE or col_distance >= MIN_COL_DISTANCE
end

-- Buffer enter handler
function M.on_buffer_enter()
    if not state.initialized then return end

    local current_buf = vim.api.nvim_get_current_buf()
    local buf_name = vim.api.nvim_buf_get_name(current_buf)

    -- Skip special buffers
    if M.is_special_buffer(buf_name) then return end

    -- Auto-switch project context
    history_manager.auto_switch_project()

    -- Record buffer switch as a jump
    M.schedule_jump_recording(JUMP_TYPES.BUFFER_SWITCH, state.buffer_change_debounce_ms)
end

-- Buffer leave handler
function M.on_buffer_leave()
    if not state.initialized then return end

    -- Record any pending jump before leaving buffer
    if state.pending_jump then M.record_pending_jump(state.pending_jump.type) end
end

-- Window enter handler
function M.on_window_enter()
    if not state.initialized then return end

    local current_win = vim.api.nvim_get_current_win()

    -- Record window switch if different from last window
    if state.last_window and current_win ~= state.last_window then
        M.schedule_jump_recording(JUMP_TYPES.WINDOW_SWITCH, state.jump_debounce_ms)
    end
end

-- Window leave handler
function M.on_window_leave()
    if not state.initialized then return end

    -- Update last window
    state.last_window = vim.api.nvim_get_current_win()
end

-- Command line leave handler (for jumplist commands)
function M.on_cmdline_leave()
    if not state.initialized then return end

    local cmdline = vim.fn.getcmdline()
    local cmdtype = vim.fn.getcmdtype()

    -- Check for jumplist commands
    if cmdtype == ":" and (cmdline:match("^%d*Ctrl%-%u") or cmdline:match("^%d*<C%-%u>")) then
        -- This is a control command, check if it's jumplist related
        local last_char = cmdline:sub(-1)
        if last_char == "O" or last_char == "I" then
            local jump_type = (last_char == "O") and JUMP_TYPES.JUMPLIST_BACKWARD or JUMP_TYPES.JUMPLIST_FORWARD
            M.schedule_jump_recording(jump_type, state.jump_debounce_ms)
        end
    end
end

-- LSP event handlers
function M.on_lsp_definition_jump(result)
    if not result or #result == 0 then return end

    M.schedule_jump_recording(JUMP_TYPES.LSP_DEFINITION, state.jump_debounce_ms)
end

function M.on_lsp_references_jump(result)
    if not result or #result == 0 then return end

    M.schedule_jump_recording(JUMP_TYPES.LSP_REFERENCES, state.jump_debounce_ms)
end

function M.on_lsp_implementation_jump(result)
    if not result or #result == 0 then return end

    M.schedule_jump_recording(JUMP_TYPES.LSP_IMPLEMENTATION, state.jump_debounce_ms)
end

function M.on_lsp_type_definition_jump(result)
    if not result or #result == 0 then return end

    M.schedule_jump_recording(JUMP_TYPES.LSP_TYPE_DEFINITION, state.jump_debounce_ms)
end

-- Schedule jump recording with debouncing
function M.schedule_jump_recording(jump_type, debounce_ms)
    -- Cancel existing timer
    if state.debounce_timer then vim.fn.timer_stop(state.debounce_timer) end

    -- Store pending jump
    state.pending_jump = {
        type = jump_type,
        timestamp = os.time(),
    }

    -- Schedule recording
    state.debounce_timer = vim.fn.timer_start(debounce_ms, function()
        M.record_pending_jump(jump_type)
        state.debounce_timer = nil
    end)
end

-- Record a pending jump
function M.record_pending_jump(jump_type)
    if not state.pending_jump then return end

    -- Get current location
    local current_pos = vim.api.nvim_win_get_cursor(0)
    local current_buf = vim.api.nvim_get_current_buf()
    local file_path = vim.api.nvim_buf_get_name(current_buf)

    -- Skip special buffers
    if M.is_special_buffer(file_path) then
        state.pending_jump = nil
        return
    end

    -- Get context around current position
    local context = M.get_code_context(current_buf, current_pos[1])

    -- Create location object
    local to_location = {
        file_path = file_path,
        position = {
            line = current_pos[1],
            column = current_pos[2] + 1, -- Convert to 1-based indexing
        },
        context = context,
    }

    -- Record the jump
    local success, entry = history_manager.record_jump(nil, to_location, jump_type)

    if success then
        debug_utils.debug("Recorded navigation jump", {
            type = jump_type,
            file = file_path,
            position = to_location.position,
        })
    else
        debug_utils.warn("Failed to record navigation jump", entry)
    end

    -- Clear pending jump
    state.pending_jump = nil
end

-- Check if buffer is a special buffer that shouldn't be tracked
function M.is_special_buffer(buf_name)
    if not buf_name or buf_name == "" then return true end

    -- Skip special buffer types
    local special_patterns = {
        "^%[.*%]$", -- [No Name], [Scratch], etc.
        "^term://", -- Terminal buffers
        "^fugitive://", -- Fugitive buffers
        "^gitsigns://", -- Gitsigns buffers
        "^diffview://", -- Diffview buffers
    }

    for _, pattern in ipairs(special_patterns) do
        if buf_name:match(pattern) then return true end
    end

    return false
end

-- Get code context around current position
function M.get_code_context(buf, line_num)
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    if #lines == 0 then return {} end

    local context_lines = 3 -- Lines of context before and after
    local start_line = math.max(1, line_num - context_lines)
    local end_line = math.min(#lines, line_num + context_lines)

    local before_lines = {}
    local after_lines = {}

    -- Get lines before cursor
    for i = start_line, line_num - 1 do
        table.insert(before_lines, lines[i])
    end

    -- Get lines after cursor
    for i = line_num + 1, end_line do
        table.insert(after_lines, lines[i])
    end

    -- Try to extract function name from current line
    local current_line = lines[line_num] or ""
    local function_name = M.extract_function_name(current_line)

    return {
        before_lines = before_lines,
        after_lines = after_lines,
        function_name = function_name,
    }
end

-- Extract function name from a line of code
function M.extract_function_name(line)
    if not line then return nil end

    -- Common function definition patterns
    local patterns = {
        "function%s+([%w_]+)",
        "def%s+([%w_]+)",
        "fn%s+([%w_]+)",
        "func%s+([%w_]+)",
        "([%w_]+)%s*%(",
    }

    for _, pattern in ipairs(patterns) do
        local match = line:match(pattern)
        if match then return match end
    end

    return nil
end

-- Classify jump type based on context
function M.classify_jump_type()
    -- This is a more advanced classification that could be expanded
    -- For now, we rely on the event handlers to classify jumps
    -- Future enhancement could analyze movement patterns

    return JUMP_TYPES.MANUAL
end

-- Get current jump types (for external use)
function M.get_jump_types() return JUMP_TYPES end

-- Cleanup function
function M.cleanup()
    if state.debounce_timer then
        vim.fn.timer_stop(state.debounce_timer)
        state.debounce_timer = nil
    end

    state.pending_jump = nil
    state.initialized = false
end

return M
