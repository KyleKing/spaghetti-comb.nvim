local M = {}

function M.get_cursor_symbol()
    local cursor = vim.api.nvim_win_get_cursor(0)
    local line = cursor[1] - 1
    local col = cursor[2]
    local bufnr = vim.api.nvim_get_current_buf()
    local filetype = vim.api.nvim_buf_get_option(bufnr, "filetype")

    local node = vim.treesitter.get_node({
        bufnr = bufnr,
        pos = { line, col },
    })

    if not node then return M.get_word_under_cursor() end

    local text = vim.treesitter.get_node_text(node, bufnr)
    local symbol_type = M.classify_symbol_type(node, filetype)

    return {
        text = text,
        node = node,
        line = line,
        col = col,
        bufnr = bufnr,
        type = symbol_type,
        language = M.get_buffer_language(),
        context = M.get_symbol_context(node, bufnr),
    }
end

function M.get_buffer_language()
    local bufnr = vim.api.nvim_get_current_buf()
    local filetype = vim.api.nvim_buf_get_option(bufnr, "filetype")

    local language_map = {
        typescript = "typescript",
        javascript = "javascript",
        python = "python",
        rust = "rust",
        go = "go",
        lua = "lua",
    }

    return language_map[filetype] or filetype
end

function M.normalize_path(path)
    if not path then return nil end
    return vim.fn.fnamemodify(path, ":p")
end

function M.get_relative_path(path)
    if not path then return nil end
    return vim.fn.fnamemodify(path, ":~:.")
end

function M.is_valid_location(loc) return loc ~= nil and loc.uri ~= nil and loc.range ~= nil end

function M.uri_to_path(uri)
    if not uri then return nil end
    return vim.uri_to_fname(uri)
end

function M.path_to_uri(path)
    if not path then return nil end
    return vim.uri_from_fname(path)
end

function M.get_line_text(bufnr, line_num)
    if not vim.api.nvim_buf_is_valid(bufnr) then return nil end

    local lines = vim.api.nvim_buf_get_lines(bufnr, line_num, line_num + 1, false)
    return lines[1] or ""
end

function M.create_location_item(uri, range, text)
    local path = M.uri_to_path(uri)
    local relative_path = M.get_relative_path(path)

    return {
        uri = uri,
        path = path,
        relative_path = relative_path,
        range = range,
        line = range.start.line + 1,
        col = range.start.character + 1,
        text = text or "",
        type = "location",
    }
end

function M.debounce(fn, ms)
    local timer = vim.loop.new_timer()
    return function(...)
        local args = { ... }
        timer:stop()
        timer:start(ms, 0, function()
            vim.schedule(function() fn(unpack(args)) end)
        end)
    end
end

-- Global logging configuration
local log_config = {
    silent_mode = false,
    show_debug = false,
    show_trace = false,
}

function M.set_log_config(config) log_config = vim.tbl_extend("force", log_config, config or {}) end

function M.get_log_config() return vim.deepcopy(log_config) end

function M.log(level, msg, opts)
    opts = opts or {}

    if type(msg) == "table" then msg = vim.inspect(msg) end

    -- Skip logging if silent mode is enabled and this isn't an error/warning
    if log_config.silent_mode and level < vim.log.levels.WARN then return end

    -- Skip debug messages unless explicitly enabled
    if level == vim.log.levels.DEBUG and not log_config.show_debug then return end

    -- Skip trace messages unless explicitly enabled
    if level == vim.log.levels.TRACE and not log_config.show_trace then return end

    local prefix = opts.no_prefix and "" or "[SpaghettiCombv2] "
    vim.notify(prefix .. msg, level)
end

function M.error(msg, opts) M.log(vim.log.levels.ERROR, msg, opts) end

function M.warn(msg, opts) M.log(vim.log.levels.WARN, msg, opts) end

function M.info(msg, opts) M.log(vim.log.levels.INFO, msg, opts) end

function M.debug(msg, opts) M.log(vim.log.levels.DEBUG, msg, opts) end

function M.trace(msg, opts) M.log(vim.log.levels.TRACE, msg, opts) end

-- Convenience functions for common logging patterns
function M.log_action(action, details)
    if log_config.silent_mode then return end
    M.debug(string.format("Action: %s - %s", action, details or ""))
end

function M.log_navigation(msg) M.trace("Navigation: " .. msg) end

function M.log_ui_change(msg) M.trace("UI: " .. msg) end

function M.log_lsp_error(msg) M.debug("[lsp_error] " .. msg) end

function M.get_word_under_cursor()
    local cursor = vim.api.nvim_win_get_cursor(0)
    local line = cursor[1] - 1
    local col = cursor[2]
    local bufnr = vim.api.nvim_get_current_buf()

    local line_text = vim.api.nvim_buf_get_lines(bufnr, line, line + 1, false)[1] or ""

    local start_col = col
    local end_col = col

    while start_col > 0 and line_text:sub(start_col, start_col):match("[%w_]") do
        start_col = start_col - 1
    end
    start_col = start_col + 1

    while end_col <= #line_text and line_text:sub(end_col + 1, end_col + 1):match("[%w_]") do
        end_col = end_col + 1
    end

    local text = line_text:sub(start_col, end_col)

    if text == "" or not text:match("^[%w_]+$") then return nil end

    return {
        text = text,
        node = nil,
        line = line,
        col = start_col - 1,
        bufnr = bufnr,
        type = "identifier",
        language = M.get_buffer_language(),
        context = nil,
    }
end

function M.classify_symbol_type(node, filetype)
    if not node then return "unknown" end

    local node_type = node:type()

    local type_mappings = {
        typescript = {
            identifier = "identifier",
            function_declaration = "function",
            method_definition = "method",
            class_declaration = "class",
            interface_declaration = "interface",
            type_alias_declaration = "type",
            variable_declaration = "variable",
            call_expression = "call",
            property_identifier = "property",
        },
        javascript = {
            identifier = "identifier",
            function_declaration = "function",
            method_definition = "method",
            class_declaration = "class",
            variable_declaration = "variable",
            call_expression = "call",
            property_identifier = "property",
        },
        python = {
            identifier = "identifier",
            function_definition = "function",
            class_definition = "class",
            call = "call",
            attribute = "attribute",
        },
        rust = {
            identifier = "identifier",
            function_item = "function",
            struct_item = "struct",
            enum_item = "enum",
            impl_item = "impl",
            trait_item = "trait",
            call_expression = "call",
        },
        go = {
            identifier = "identifier",
            function_declaration = "function",
            type_declaration = "type",
            method_declaration = "method",
            call_expression = "call",
        },
    }

    local mapping = type_mappings[filetype] or {}
    return mapping[node_type] or node_type
end

function M.get_symbol_context(node, bufnr)
    if not node then return nil end

    local parent = node:parent()
    local context = {}

    while parent do
        local parent_type = parent:type()
        local parent_text = vim.treesitter.get_node_text(parent, bufnr)

        if parent_type:match("function") or parent_type:match("class") or parent_type:match("method") then
            table.insert(context, {
                type = parent_type,
                text = parent_text:sub(1, 50),
            })
        end

        parent = parent:parent()
        if #context >= 3 then break end
    end

    return context
end

function M.extract_symbol_info(symbol_data, language)
    if not symbol_data then return {} end

    local extractors = {
        typescript = M.extract_typescript_symbol_info,
        javascript = M.extract_javascript_symbol_info,
        python = M.extract_python_symbol_info,
        rust = M.extract_rust_symbol_info,
        go = M.extract_go_symbol_info,
    }

    local extractor = extractors[language] or M.extract_generic_symbol_info
    return extractor(symbol_data)
end

function M.extract_typescript_symbol_info(data)
    local info = M.extract_generic_symbol_info(data)

    if data.node then
        local node_type = data.node:type()
        if node_type == "call_expression" then
            info.is_function_call = true
        elseif node_type:match("interface") then
            info.is_interface = true
        elseif node_type:match("type") then
            info.is_type_definition = true
        end
    end

    return info
end

function M.extract_javascript_symbol_info(data) return M.extract_typescript_symbol_info(data) end

function M.extract_python_symbol_info(data)
    local info = M.extract_generic_symbol_info(data)

    if data.node then
        local node_type = data.node:type()
        if node_type == "call" then
            info.is_function_call = true
        elseif node_type == "attribute" then
            info.is_attribute_access = true
        end
    end

    return info
end

function M.extract_rust_symbol_info(data)
    local info = M.extract_generic_symbol_info(data)

    if data.node then
        local node_type = data.node:type()
        if node_type:match("impl") then
            info.is_implementation = true
        elseif node_type:match("trait") then
            info.is_trait = true
        end
    end

    return info
end

function M.extract_go_symbol_info(data)
    local info = M.extract_generic_symbol_info(data)

    if data.node then
        local node_type = data.node:type()
        if node_type == "call_expression" then info.is_function_call = true end
    end

    return info
end

function M.extract_generic_symbol_info(data)
    return {
        symbol = data.text,
        type = data.type or "unknown",
        language = data.language,
        file = vim.api.nvim_buf_get_name(data.bufnr),
        line = data.line + 1,
        col = data.col + 1,
        context = data.context,
        timestamp = os.time(),
        bookmarked = false,
    }
end

function M.get_project_root()
    local current_dir = vim.fn.getcwd()

    local markers = { ".git", "package.json", "Cargo.toml", "go.mod", "pyproject.toml", "setup.py" }

    local function find_root(path)
        for _, marker in ipairs(markers) do
            if vim.fn.isdirectory(path .. "/" .. marker) == 1 or vim.fn.filereadable(path .. "/" .. marker) == 1 then
                return path
            end
        end

        local parent = vim.fn.fnamemodify(path, ":h")
        if parent == path then return nil end

        return find_root(parent)
    end

    return find_root(current_dir) or current_dir
end

function M.get_git_branch()
    local git_dir = vim.fn.finddir(".git", vim.fn.getcwd() .. ";")
    if git_dir == "" then return nil end

    local branch_file = git_dir .. "/HEAD"
    if vim.fn.filereadable(branch_file) == 0 then return nil end

    local head_content = vim.fn.readfile(branch_file)
    if not head_content or #head_content == 0 then return nil end

    local head_line = head_content[1]
    local branch = head_line:match("ref: refs/heads/(.+)")

    return branch or "HEAD"
end

return M
