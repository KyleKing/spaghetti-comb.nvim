-- LSP integration hooks
local M = {}

-- Dependencies
local history_manager = nil
local debug_utils = nil
local project_utils = nil

-- Module state
local state = {
    initialized = false,
    lsp_available = false,
    reference_locations = {},
    current_reference_index = 0,
}

-- Initialize the LSP integration module
function M.setup(config)
    if state.initialized then return end

    -- Load dependencies
    history_manager = require("spaghetti-comb.history.manager")
    debug_utils = require("spaghetti-comb.utils.debug")
    project_utils = require("spaghetti-comb.utils.project")

    -- Setup dependencies
    debug_utils.setup(config.debug or {})
    history_manager.setup(config)

    -- Check LSP availability
    M.check_lsp_availability()

    -- Set up autocmds for LSP events
    M.setup_lsp_autocmds()

    state.initialized = true
    debug_utils.info("LSP integration initialized", { lsp_available = state.lsp_available })
end

-- Check if LSP is available
function M.check_lsp_availability()
    local clients = vim.lsp.get_active_clients()
    state.lsp_available = clients and #clients > 0
    return state.lsp_available
end

-- Set up autocmds for LSP events
function M.setup_lsp_autocmds()
    -- Hook into LSP definition jumps
    vim.api.nvim_create_autocmd("LspAttach", {
        callback = function(args)
            local client = vim.lsp.get_client_by_id(args.data.client_id)
            if not client then return end

            -- Hook into LSP requests
            M.hook_lsp_requests(client)
        end,
    })

    -- Hook into buffer changes to detect LSP navigation
    vim.api.nvim_create_autocmd({ "CursorMoved", "BufEnter" }, {
        callback = function() M.handle_cursor_movement() end,
    })
end

-- Hook into LSP requests to track navigation
function M.hook_lsp_requests(client)
    if not client then return end

    -- Store original LSP methods
    local original_definition = client.request
    local original_references = client.request
    local original_implementation = client.request

    -- Override request method to intercept LSP calls
    client.request = function(method, params, handler, ...)
        -- Track definition requests
        if method == "textDocument/definition" then
            debug_utils.debug("LSP definition request intercepted", { params = params })
            return original_definition(method, params, function(err, result, ctx, config)
                if not err and result then M.handle_definition_result(params, result) end
                return handler(err, result, ctx, config)
            end, ...)
        end

        -- Track references requests
        if method == "textDocument/references" then
            debug_utils.debug("LSP references request intercepted", { params = params })
            return original_references(method, params, function(err, result, ctx, config)
                if not err and result then M.handle_references_result(params, result) end
                return handler(err, result, ctx, config)
            end, ...)
        end

        -- Track implementation requests
        if method == "textDocument/implementation" then
            debug_utils.debug("LSP implementation request intercepted", { params = params })
            return original_implementation(method, params, function(err, result, ctx, config)
                if not err and result then M.handle_implementation_result(params, result) end
                return handler(err, result, ctx, config)
            end, ...)
        end

        -- Call original method for other requests
        return original_definition(method, params, handler, ...)
    end
end

-- Handle cursor movement to detect LSP jumps
local last_position = nil
function M.handle_cursor_movement()
    if not state.initialized then return end

    local current_buf = vim.api.nvim_get_current_buf()
    local current_pos = vim.api.nvim_win_get_cursor(0)

    if not last_position then
        last_position = { buf = current_buf, pos = current_pos }
        return
    end

    -- Check if this is a significant jump (different buffer or large position change)
    local buf_changed = current_buf ~= last_position.buf
    local line_changed = math.abs(current_pos[1] - last_position.pos[1]) > 5
    local col_changed = math.abs(current_pos[2] - last_position.pos[2]) > 20

    if buf_changed or (line_changed and col_changed) then
        -- This might be an LSP jump, record it
        local from_location = {
            file_path = vim.api.nvim_buf_get_name(last_position.buf),
            position = {
                line = last_position.pos[1],
                column = last_position.pos[2],
            },
            context = M.get_context_at_position(last_position.buf, last_position.pos),
        }

        local to_location = {
            file_path = vim.api.nvim_buf_get_name(current_buf),
            position = {
                line = current_pos[1],
                column = current_pos[2],
            },
            context = M.get_context_at_position(current_buf, current_pos),
        }

        -- Record the jump if we have valid locations
        if from_location.file_path ~= "" and to_location.file_path ~= "" then
            history_manager.record_jump(from_location, to_location, "lsp_jump")
            debug_utils.debug("Recorded LSP jump", {
                from = from_location.file_path .. ":" .. from_location.position.line,
                to = to_location.file_path .. ":" .. to_location.position.line,
            })
        end
    end

    last_position = { buf = current_buf, pos = current_pos }
end

-- Get code context at a specific position
function M.get_context_at_position(bufnr, position)
    if not bufnr or not position then return {} end

    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    if #lines == 0 then return {} end

    local line_num = position[1] - 1 -- Convert to 0-based
    local col_num = position[2]

    -- Get context lines
    local before_lines = {}
    local after_lines = {}

    -- Get lines before cursor (up to 3 lines)
    for i = math.max(0, line_num - 3), line_num - 1 do
        if lines[i + 1] then table.insert(before_lines, lines[i + 1]) end
    end

    -- Get lines after cursor (up to 3 lines)
    for i = line_num + 1, math.min(#lines - 1, line_num + 3) do
        if lines[i + 1] then table.insert(after_lines, lines[i + 1]) end
    end

    -- Get current line and extract function name if possible
    local current_line = lines[line_num + 1] or ""
    local function_name = M.extract_function_name(current_line)

    return {
        before_lines = before_lines,
        after_lines = after_lines,
        function_name = function_name,
        current_line = current_line,
    }
end

-- Extract function name from a line of code
function M.extract_function_name(line)
    if not line then return nil end

    -- Common function patterns
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

-- LSP event hooks
function M.on_definition_jump(from_pos, to_pos)
    if not state.initialized then return end

    debug_utils.debug("Definition jump detected", { from = from_pos, to = to_pos })

    local from_location = {
        file_path = vim.api.nvim_buf_get_name(0),
        position = from_pos,
        context = M.get_context_at_position(0, { from_pos.line + 1, from_pos.character }),
    }

    local to_location = {
        file_path = vim.api.nvim_buf_get_name(0), -- Assume same buffer for now
        position = to_pos,
        context = M.get_context_at_position(0, { to_pos.line + 1, to_pos.character }),
    }

    history_manager.record_jump(from_location, to_location, "lsp_definition")
end

function M.on_references_found(locations)
    if not state.initialized then return end

    debug_utils.debug("References found", { count = #locations })

    -- Store references for navigation
    state.reference_locations = locations or {}
    state.current_reference_index = 0

    -- Record the initial reference search
    if #locations > 0 then
        local current_pos = vim.api.nvim_win_get_cursor(0)
        local from_location = {
            file_path = vim.api.nvim_buf_get_name(0),
            position = {
                line = current_pos[1],
                column = current_pos[2],
            },
            context = M.get_context_at_position(0, current_pos),
        }

        -- Record jump to first reference
        local first_ref = locations[1]
        if first_ref and first_ref.uri then
            local to_location = {
                file_path = vim.uri_to_fname(first_ref.uri),
                position = {
                    line = first_ref.range.start.line + 1,
                    column = first_ref.range.start.character,
                },
                context = {}, -- Will be populated when we navigate there
            }

            history_manager.record_jump(from_location, to_location, "lsp_reference")
        end
    end
end

function M.on_implementation_jump(from_pos, to_pos)
    if not state.initialized then return end

    debug_utils.debug("Implementation jump detected", { from = from_pos, to = to_pos })

    local from_location = {
        file_path = vim.api.nvim_buf_get_name(0),
        position = from_pos,
        context = M.get_context_at_position(0, { from_pos.line + 1, from_pos.character }),
    }

    local to_location = {
        file_path = vim.api.nvim_buf_get_name(0), -- Assume same buffer for now
        position = to_pos,
        context = M.get_context_at_position(0, { to_pos.line + 1, to_pos.character }),
    }

    history_manager.record_jump(from_location, to_location, "lsp_implementation")
end

-- Handle LSP results
function M.handle_definition_result(params, result)
    if not result then return end

    -- Convert LSP result to our format
    local locations = M.lsp_result_to_locations(result)
    if #locations > 0 then M.on_references_found(locations) end
end

function M.handle_references_result(params, result)
    if not result then return end

    -- Convert LSP result to our format
    local locations = M.lsp_result_to_locations(result)
    M.on_references_found(locations)
end

function M.handle_implementation_result(params, result)
    if not result then return end

    -- Convert LSP result to our format
    local locations = M.lsp_result_to_locations(result)
    if #locations > 0 then
        -- For implementation, we jump to the first result
        local first_loc = locations[1]
        if first_loc then
            M.on_implementation_jump(
                { line = params.position.line, character = params.position.character },
                { line = first_loc.range.start.line, character = first_loc.range.start.character }
            )
        end
    end
end

-- Convert LSP result to location format
function M.lsp_result_to_locations(result)
    if not result then return {} end

    local locations = {}

    -- Handle single location
    if result.uri then
        table.insert(locations, result)
    -- Handle array of locations
    elseif type(result) == "table" and #result > 0 then
        for _, loc in ipairs(result) do
            if loc.uri then table.insert(locations, loc) end
        end
    end

    return locations
end

-- Enhanced LSP commands that extend built-in functionality
function M.enhanced_go_to_definition()
    if not state.initialized then
        vim.notify("Spaghetti Comb LSP integration not initialized", vim.log.levels.WARN)
        return
    end

    if not M.check_lsp_availability() then
        debug_utils.warn("LSP not available, falling back to basic navigation")
        -- Fallback: try to find definition using basic text search
        M.fallback_go_to_definition()
        return
    end

    -- Record current position before LSP call
    local current_pos = vim.api.nvim_win_get_cursor(0)
    local from_location = {
        file_path = vim.api.nvim_buf_get_name(0),
        position = {
            line = current_pos[1],
            column = current_pos[2],
        },
        context = M.get_context_at_position(0, current_pos),
    }

    -- Call LSP go-to-definition
    vim.lsp.buf.definition({
        on_list = function(options)
            -- This callback is called when there are multiple definitions
            if options and options.items and #options.items > 1 then
                -- Store locations for potential navigation
                state.reference_locations = options.items
                state.current_reference_index = 0
            end
        end,
    })

    debug_utils.debug("Enhanced go-to-definition called")
end

function M.enhanced_find_references()
    if not state.initialized then
        vim.notify("Spaghetti Comb LSP integration not initialized", vim.log.levels.WARN)
        return
    end

    if not M.check_lsp_availability() then
        debug_utils.warn("LSP not available, falling back to basic reference search")
        M.fallback_find_references()
        return
    end

    -- Call LSP find references
    vim.lsp.buf.references({
        includeDeclaration = false,
        on_list = function(options)
            -- Store references for navigation
            if options and options.items then
                state.reference_locations = options.items
                state.current_reference_index = 0

                debug_utils.debug("Found references", { count = #options.items })

                -- If we have references, show them with preview
                if #options.items > 0 then M.show_references_with_preview() end
            end
        end,
    })

    debug_utils.debug("Enhanced find-references called")
end

function M.enhanced_go_to_implementation()
    if not state.initialized then
        vim.notify("Spaghetti Comb LSP integration not initialized", vim.log.levels.WARN)
        return
    end

    if not M.check_lsp_availability() then
        debug_utils.warn("LSP not available, falling back to basic implementation search")
        M.fallback_go_to_implementation()
        return
    end

    -- Call LSP go-to-implementation
    vim.lsp.buf.implementation()

    debug_utils.debug("Enhanced go-to-implementation called")
end

-- Fallback implementations when LSP is not available
function M.fallback_go_to_definition()
    -- Basic fallback: search for function definition in current file
    local current_word = vim.fn.expand("<cword>")
    if current_word == "" then return end

    -- Search for function definition patterns
    local patterns = {
        "function%s+" .. vim.pesc(current_word),
        "def%s+" .. vim.pesc(current_word),
        "fn%s+" .. vim.pesc(current_word),
        "func%s+" .. vim.pesc(current_word),
    }

    for _, pattern in ipairs(patterns) do
        local line_num = vim.fn.search(pattern, "nw")
        if line_num > 0 then
            vim.api.nvim_win_set_cursor(0, { line_num, 0 })
            debug_utils.info("Fallback: found definition at line " .. line_num)
            return
        end
    end

    vim.notify("Definition not found", vim.log.levels.INFO)
end

function M.fallback_find_references()
    -- Basic fallback: search for word occurrences in current file
    local current_word = vim.fn.expand("<cword>")
    if current_word == "" then return end

    -- Use vim's grep to find references
    vim.cmd("vimgrep /" .. vim.pesc(current_word) .. "/ %")
    vim.cmd("copen")

    debug_utils.info("Fallback: searched for references of '" .. current_word .. "'")
end

function M.fallback_go_to_implementation()
    -- Basic fallback: similar to definition but look for implementation patterns
    local current_word = vim.fn.expand("<cword>")
    if current_word == "" then return end

    -- Search for implementation patterns
    local patterns = {
        "impl%s+" .. vim.pesc(current_word),
        "class%s+" .. vim.pesc(current_word),
        "struct%s+" .. vim.pesc(current_word),
    }

    for _, pattern in ipairs(patterns) do
        local line_num = vim.fn.search(pattern, "nw")
        if line_num > 0 then
            vim.api.nvim_win_set_cursor(0, { line_num, 0 })
            debug_utils.info("Fallback: found implementation at line " .. line_num)
            return
        end
    end

    vim.notify("Implementation not found", vim.log.levels.INFO)
end

-- Reference navigation with previews
function M.show_references_with_preview()
    if #state.reference_locations == 0 then
        vim.notify("No references found", vim.log.levels.INFO)
        return
    end

    -- Create a quickfix list from references
    local qf_items = {}
    for _, ref in ipairs(state.reference_locations) do
        table.insert(qf_items, {
            filename = vim.uri_to_fname(ref.uri),
            lnum = ref.range.start.line + 1,
            col = ref.range.start.character + 1,
            text = ref.uri, -- This will be replaced with actual line content
        })
    end

    -- Set quickfix list
    vim.fn.setqflist(qf_items)
    vim.cmd("copen")

    debug_utils.debug("Showing references with preview", { count = #qf_items })
end

function M.navigate_references(direction)
    if #state.reference_locations == 0 then
        vim.notify("No references to navigate", vim.log.levels.INFO)
        return
    end

    if direction == "next" then
        state.current_reference_index = (state.current_reference_index % #state.reference_locations) + 1
    elseif direction == "prev" then
        state.current_reference_index = state.current_reference_index - 1
        if state.current_reference_index < 1 then state.current_reference_index = #state.reference_locations end
    else
        vim.notify("Invalid direction. Use 'next' or 'prev'", vim.log.levels.ERROR)
        return
    end

    local ref = state.reference_locations[state.current_reference_index]
    if ref then
        -- Jump to the reference
        vim.cmd("edit " .. vim.uri_to_fname(ref.uri))
        vim.api.nvim_win_set_cursor(0, { ref.range.start.line + 1, ref.range.start.character + 1 })

        debug_utils.debug("Navigated to reference", {
            index = state.current_reference_index,
            file = vim.uri_to_fname(ref.uri),
            line = ref.range.start.line + 1,
        })
    end
end

return M
